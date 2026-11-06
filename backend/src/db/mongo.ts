import * as os from 'node:os';
import mongoose from 'mongoose';

export async function connectMongo(url: string): Promise<void> {
  await mongoose.connect(url, {
    serverSelectionTimeoutMS: 5000,
    // The driver loads `os` with a dynamic import() for its handshake metadata.
    // That import fails inside Jest's sandbox, the metadata ends up empty and
    // the server refuses the connection ("Missing required sub-document
    // 'driver'"). Passing the module directly avoids the dynamic import.
    runtimeAdapters: { os },
  });
}

export async function disconnectMongo(): Promise<void> {
  await mongoose.disconnect();
}
