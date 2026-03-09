import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  // Expect path like /news-preview/<newsId>
  const newsId = url.pathname.split("/").filter(Boolean).pop() ?? "";

  if (!newsId) {
    return new Response("Not found", { status: 404 });
  }

  const supabaseUrl = (globalThis as any).Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = (globalThis as any).Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data, error } = await supabase
    .from("newspresso_aggregated_news_in")
    .select("content_title, content_description, url_to_image")
    .eq("id", newsId)
    .maybeSingle();

  if (error || !data) {
    return new Response("Not found", { status: 404 });
  }

  const title = escapeHtml(data.content_title ?? "Newspresso");
  const description = escapeHtml(
    data.content_description ?? "Get your daily dose of unbiased news with AI-generated summaries."
  );
  const image = escapeHtml(data.url_to_image ?? "");
  const pageUrl = escapeHtml(`https://www.newspresso.org/news/${newsId}`);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title}</title>

  <!-- Open Graph -->
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${description}">
  <meta property="og:image" content="${image}">
  <meta property="og:url" content="${pageUrl}">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="Newspresso">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${title}">
  <meta name="twitter:description" content="${description}">
  <meta name="twitter:image" content="${image}">
</head>
<body>
  <p>Opening in Newspresso...</p>
  <script>window.location.href = "${pageUrl}";</script>
</body>
</html>`;

  const headers = new Headers();
  headers.set("Content-Type", "text/html; charset=utf-8");
  headers.set("Cache-Control", "public, max-age=600");

  return new Response(html, { status: 200, headers });
});
