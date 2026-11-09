import { createApp } from './app';
import { env } from './config/env';
import { connectMongo, disconnectMongo } from './db/mongo';
import { initPush } from './modules/push/fcm';
import { backfillRoles } from './modules/users/user.model';

async function main(): Promise<void> {
  await connectMongo(env.MONGO_URL);
  const backfilled = await backfillRoles();
  if (backfilled > 0) console.info(`Gave the student role to ${backfilled} older account(s).`);
  await initPush(); // logs whether push notifications are on (never throws)
  const server = createApp().listen(env.PORT, env.HOST, () => {
    console.info(`CampusPulse API listening on http://${env.HOST}:${env.PORT}/api`);
  });

  const shutdown = () => {
    server.close(() => {
      void disconnectMongo().finally(() => process.exit(0));
    });
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err: unknown) => {
  console.error('Failed to start the API:', err);
  process.exit(1);
});
