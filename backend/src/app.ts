import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.routes';
import { errorHandler, notFound } from './middleware/errorHandler';

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);

app.get('/api/health', (_, res) => {
  res.json({ success: true, message: 'API is running' });
});

app.use(notFound);
app.use(errorHandler);

export default app;
