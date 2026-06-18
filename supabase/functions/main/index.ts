// Edge-runtime "main" router for self-hosted Supabase.
// Routes /<function-name> to /home/deno/functions/<function-name> and forwards
// the container's env vars (incl. APNS_*) to the function worker.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (req: Request) => {
  const url = new URL(req.url);
  const serviceName = url.pathname.split("/")[1];

  if (!serviceName || serviceName === "") {
    return new Response("ok", { status: 200 });
  }

  const servicePath = `/home/deno/functions/${serviceName}`;
  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath,
      memoryLimitMb: 150,
      workerTimeoutMs: 5 * 60 * 1000,
      noModuleCache: false,
      importMapPath: null,
      envVars: Object.entries(Deno.env.toObject()),
    });
    return await worker.fetch(req);
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
