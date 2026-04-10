import Prism from "./Prism";
import DataPacket from "./proto/DataPacket";
import DataRequest from "./proto/requests/DataRequest";
import LoginRequest from "./proto/requests/LoginRequest";
import { PacketType } from "./proto/Types";

const host = process.env.PRISM_HOST ?? "127.0.0.1";
const port = Number(process.env.PRISM_PORT ?? "6969");
const key = process.env.PRISM_KEY ?? "secret-auth-key-123=============";
const clients = Number(process.env.PRISM_CLIENTS ?? "10");
const requestsPerClient = Number(process.env.PRISM_REQUESTS_PER_CLIENT ?? "100");

type Sample = { ok: boolean; durationMs: number };

const percentile = (values: number[], p: number): number => {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.max(0, Math.min(sorted.length - 1, Math.round((sorted.length - 1) * p)));
  return sorted[idx]!;
};

const runClient = async (id: number): Promise<Sample[]> => {
  const prism = new Prism(host, port, key);
  prism.start();

  await prism.send(
    LoginRequest.encode({
      service: "default_service",
      token: "default_token"
    }).finish(),
    PacketType.DATA
  );

  const samples: Sample[] = [];

  for (let i = 0; i < requestsPerClient; i += 1) {
    const payload = DataPacket.encode({
      type: 5,
      request: new DataRequest({
        type: 1,
        payload: JSON.stringify({ client: id, request: i, now: Date.now() })
      })
    }).finish();

    const start = performance.now();
    try {
      await prism.send(payload, PacketType.DATA);
      samples.push({ ok: true, durationMs: performance.now() - start });
    } catch {
      samples.push({ ok: false, durationMs: performance.now() - start });
    }
  }

  return samples;
};

const startedAt = performance.now();
const results = await Promise.all(Array.from({ length: clients }, (_, idx) => runClient(idx + 1)));
const allSamples = results.flat();
const okSamples = allSamples.filter((s) => s.ok).map((s) => s.durationMs);
const failed = allSamples.length - okSamples.length;
const durationSeconds = (performance.now() - startedAt) / 1000;

console.log("=== Prism Load Test ===");
console.log(`target=${host}:${port}`);
console.log(`clients=${clients} requests_per_client=${requestsPerClient}`);
console.log(`total_requests=${allSamples.length} ok=${okSamples.length} failed=${failed}`);
console.log(`throughput_rps=${(allSamples.length / durationSeconds).toFixed(2)}`);
console.log(`p50_ms=${percentile(okSamples, 0.5).toFixed(2)}`);
console.log(`p95_ms=${percentile(okSamples, 0.95).toFixed(2)}`);
console.log(`p99_ms=${percentile(okSamples, 0.99).toFixed(2)}`);
