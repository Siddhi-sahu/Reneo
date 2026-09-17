create extension if not exists pgcrypto;

-- Role Definition 
create type public.user_role as enum ('SELLER', 'CUSTOMER');
create type public.product_status as enum ('ACTIVE', 'ARCHIVED');
create type public.order_status as enum ('PENDING', 'CONFIRMED', 'CANCELLED');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  role public.user_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_full_name_length check (
    full_name is null or char_length(full_name) <= 120
  )
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles (id) on delete restrict,
  name text not null,
  slug text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stores_name_length check (char_length(name) between 2 and 120),
  constraint stores_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create unique index stores_seller_id_unique_idx on public.stores (seller_id);
create unique index stores_slug_unique_idx on public.stores (lower(slug));

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete restrict,
  name text not null,
  description text,
  category text not null,
  sku text,
  price_amount bigint not null,
  currency text not null default 'XOF',
  status public.product_status not null default 'ACTIVE',
  archived_at timestamptz,
  search_document tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(category, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(description, '')), 'C')
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_name_length check (char_length(name) between 2 and 160),
  constraint products_category_length check (char_length(category) between 2 and 80),
  constraint products_price_positive check (price_amount > 0),
  constraint products_currency_iso check (currency ~ '^[A-Z]{3}$'),
  constraint products_active_not_archived check (
    status = 'ARCHIVED' or archived_at is null
  )
);

create unique index products_store_sku_unique_idx
  on public.products (store_id, lower(sku))
  where sku is not null;

create index products_store_status_idx on public.products (store_id, status);
create index products_category_price_idx on public.products (category, price_amount);
create index products_price_idx on public.products (price_amount);
create index products_search_document_idx on public.products using gin (search_document);

create table public.inventory (
  product_id uuid primary key references public.products (id) on delete cascade,
  quantity_available integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint inventory_quantity_available_non_negative check (quantity_available >= 0)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles (id) on delete restrict,
  status public.order_status not null default 'PENDING',
  total_amount bigint not null default 0,
  currency text not null default 'XOF',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_total_amount_non_negative check (total_amount >= 0),
  constraint orders_currency_iso check (currency ~ '^[A-Z]{3}$')
);

create index orders_customer_created_at_idx on public.orders (customer_id, created_at desc);
create index orders_status_created_at_idx on public.orders (status, created_at desc);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  store_id uuid not null references public.stores (id) on delete restrict,
  seller_id uuid not null references public.profiles (id) on delete restrict,
  product_name text not null,
  unit_price_amount bigint not null,
  currency text not null default 'XOF',
  quantity integer not null,
  line_total_amount bigint generated always as (unit_price_amount * quantity) stored,
  created_at timestamptz not null default now(),
  constraint order_items_quantity_positive check (quantity > 0),
  constraint order_items_unit_price_positive check (unit_price_amount > 0),
  constraint order_items_currency_iso check (currency ~ '^[A-Z]{3}$')
);

create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_product_id_idx on public.order_items (product_id);
create index order_items_seller_id_idx on public.order_items (seller_id);

create table public.idempotency_keys (
  customer_id uuid not null references public.profiles (id) on delete cascade,
  key text not null,
  request_hash text not null,
  order_id uuid references public.orders (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  primary key (customer_id, key),
  constraint idempotency_keys_key_length check (char_length(key) between 8 and 160),
  constraint idempotency_keys_hash_length check (char_length(request_hash) between 32 and 128)
);

create index idempotency_keys_expires_at_idx on public.idempotency_keys (expires_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger stores_set_updated_at
before update on public.stores
for each row execute function public.set_updated_at();

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create trigger inventory_set_updated_at
before update on public.inventory
for each row execute function public.set_updated_at();

create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role public.user_role;
begin
  requested_role = case upper(coalesce(new.raw_user_meta_data ->> 'role', 'CUSTOMER'))
    when 'SELLER' then 'SELLER'::public.user_role
    else 'CUSTOMER'::public.user_role
  end;

  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    requested_role
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role then
    raise exception 'profile role cannot be changed directly' using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger profiles_prevent_role_change
before update of role on public.profiles
for each row execute function public.prevent_profile_role_change();

create or replace function public.assert_store_seller_role()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1
    from public.profiles
    where id = new.seller_id
      and role = 'SELLER'
  ) then
    raise exception 'stores.seller_id must reference a SELLER profile' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger stores_assert_seller_role
before insert or update of seller_id on public.stores
for each row execute function public.assert_store_seller_role();

create or replace function public.assert_order_customer_role()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1
    from public.profiles
    where id = new.customer_id
      and role = 'CUSTOMER'
  ) then
    raise exception 'orders.customer_id must reference a CUSTOMER profile' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger orders_assert_customer_role
before insert or update of customer_id on public.orders
for each row execute function public.assert_order_customer_role();

create or replace function public.assert_order_item_product_snapshot()
returns trigger
language plpgsql
as $$
declare
  real_store_id uuid;
  real_seller_id uuid;
begin
  select p.store_id, s.seller_id
  into real_store_id, real_seller_id
  from public.products p
  join public.stores s on s.id = p.store_id
  where p.id = new.product_id;

  if real_store_id is null then
    raise exception 'order item product does not exist' using errcode = '23503';
  end if;

  if new.store_id <> real_store_id or new.seller_id <> real_seller_id then
    raise exception 'order item seller/store snapshot does not match product' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger order_items_assert_product_snapshot
before insert or update of product_id, store_id, seller_id on public.order_items
for each row execute function public.assert_order_item_product_snapshot();

create or replace function public.current_profile_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

create or replace function public.seller_owns_store(store_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.stores
    where id = store_uuid
      and seller_id = (select auth.uid())
  );
$$;

create or replace function public.seller_owns_product(product_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.products p
    join public.stores s on s.id = p.store_id
    where p.id = product_uuid
      and s.seller_id = (select auth.uid())
  );
$$;

create or replace function public.seller_can_read_order(order_uuid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.order_items oi
    where oi.order_id = order_uuid
      and oi.seller_id = (select auth.uid())
  );
$$;

alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.idempotency_keys enable row level security;

revoke all on public.profiles from anon, authenticated;
revoke all on public.stores from anon, authenticated;
revoke all on public.products from anon, authenticated;
revoke all on public.inventory from anon, authenticated;
revoke all on public.orders from anon, authenticated;
revoke all on public.order_items from anon, authenticated;
revoke all on public.idempotency_keys from anon, authenticated;

grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;
grant select, insert, update, delete on public.stores to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.inventory to authenticated;
grant select on public.orders to authenticated;
grant select on public.order_items to authenticated;
grant select on public.idempotency_keys to authenticated;

create policy "profiles_select_own"
on public.profiles for select to authenticated
using (id = (select auth.uid()));

create policy "profiles_update_own_full_name"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "stores_select_own"
on public.stores for select to authenticated
using (seller_id = (select auth.uid()));

create policy "stores_insert_own_seller_store"
on public.stores for insert to authenticated
with check (
  seller_id = (select auth.uid())
  and public.current_profile_role() = 'SELLER'
);

create policy "stores_update_own"
on public.stores for update to authenticated
using (seller_id = (select auth.uid()))
with check (
  seller_id = (select auth.uid())
  and public.current_profile_role() = 'SELLER'
);

create policy "stores_delete_own"
on public.stores for delete to authenticated
using (seller_id = (select auth.uid()));

create policy "products_select_active_or_own"
on public.products for select to authenticated
using (
  status = 'ACTIVE'
  or public.seller_owns_store(store_id)
);

create policy "products_insert_own_store"
on public.products for insert to authenticated
with check (
  public.current_profile_role() = 'SELLER'
  and public.seller_owns_store(store_id)
);

create policy "products_update_own_store"
on public.products for update to authenticated
using (public.seller_owns_store(store_id))
with check (
  public.current_profile_role() = 'SELLER'
  and public.seller_owns_store(store_id)
);

create policy "products_delete_own_store"
on public.products for delete to authenticated
using (public.seller_owns_store(store_id));

create policy "inventory_select_active_product_or_own"
on public.inventory for select to authenticated
using (
  public.seller_owns_product(product_id)
  or exists (
    select 1
    from public.products p
    where p.id = product_id
      and p.status = 'ACTIVE'
  )
);

create policy "inventory_insert_own_product"
on public.inventory for insert to authenticated
with check (
  public.current_profile_role() = 'SELLER'
  and public.seller_owns_product(product_id)
);

create policy "inventory_update_own_product"
on public.inventory for update to authenticated
using (public.seller_owns_product(product_id))
with check (
  public.current_profile_role() = 'SELLER'
  and public.seller_owns_product(product_id)
);

create policy "inventory_delete_own_product"
on public.inventory for delete to authenticated
using (public.seller_owns_product(product_id));

create policy "orders_select_customer_or_seller"
on public.orders for select to authenticated
using (
  customer_id = (select auth.uid())
  or public.seller_can_read_order(id)
);

create policy "order_items_select_customer_or_seller"
on public.order_items for select to authenticated
using (
  seller_id = (select auth.uid())
  or exists (
    select 1
    from public.orders o
    where o.id = order_id
      and o.customer_id = (select auth.uid())
  )
);

create policy "idempotency_keys_select_own"
on public.idempotency_keys for select to authenticated
using (customer_id = (select auth.uid()));
