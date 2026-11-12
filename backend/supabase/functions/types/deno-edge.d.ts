// Ambient TypeScript declarations for Supabase Edge Functions (Deno runtime)
// used by IDE TypeScript servers when the Deno CLI/extension is not active.

declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    has(key: string): boolean;
    toObject(): Record<string, string>;
  }

  export const env: Env;

  export interface NetAddr {
    transport: "tcp" | "udp";
    hostname: string;
    port: number;
  }

  export interface UnixAddr {
    transport: "unix" | "unixpacket";
    path: string;
  }

  export type Addr = NetAddr | UnixAddr;

  export interface ServeHandlerInfo<TAddr extends Addr = NetAddr> {
    remoteAddr: TAddr;
    completed: Promise<void>;
  }

  export type ServeHandler<TAddr extends Addr = NetAddr> = (
    request: Request,
    info: ServeHandlerInfo<TAddr>
  ) => Response | Promise<Response>;

  export interface ServeOptions<TAddr extends Addr = NetAddr> {
    port?: number;
    hostname?: string;
    signal?: AbortSignal;
    onError?: (error: unknown) => Response | Promise<Response>;
    onListen?: (localAddr: TAddr) => void;
    handler?: ServeHandler<TAddr>;
  }

  export interface HttpServer {
    finished: Promise<void>;
    addr: Addr;
    ref(): void;
    unref(): void;
    shutdown(): Promise<void>;
  }

  export function serve(handler: ServeHandler): HttpServer;
  export function serve(
    options: ServeOptions,
    handler?: ServeHandler
  ): HttpServer;
}

declare module "npm:standardwebhooks@^1.0.0" {
  export interface WebhookOptions {
    format?: "raw";
  }

  export class Webhook {
    constructor(secret: string | Uint8Array, options?: WebhookOptions);
    verify(
      payload: string | Uint8Array,
      headers: Record<string, string | string[] | undefined>
    ): unknown;
    sign(msgId: string, timestamp: Date, payload: string): string;
  }
}

