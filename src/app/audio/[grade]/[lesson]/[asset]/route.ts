import { createAdminClient } from "@/lib/supabase/admin";

const SIGNED_URL_TTL_SECONDS = 60 * 60;
const DEFAULT_LOCALE = "en-US";
const ROUTE_PART = /^[a-z0-9-]+$/;

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ grade: string; lesson: string; asset: string }> }
) {
  const { grade, lesson, asset } = await params;

  if (![grade, lesson, asset].every((part) => ROUTE_PART.test(part))) {
    return Response.json({ error: "Audio asset not found." }, { status: 404 });
  }

  const supabase = createAdminClient();
  const { data: audioAsset, error } = await supabase
    .from("mac_reads_audio_assets")
    .select("storage_bucket, storage_path")
    .eq("grade_slug", grade)
    .eq("lesson_slug", lesson)
    .eq("public_slug", asset)
    .eq("locale", DEFAULT_LOCALE)
    .eq("status", "published")
    .maybeSingle();

  if (error) {
    console.error("MAC READS audio lookup failed", error);
    return Response.json({ error: "Audio is temporarily unavailable." }, { status: 503 });
  }

  if (!audioAsset) {
    return Response.json({ error: "Audio asset not found." }, { status: 404 });
  }

  const { data: signed, error: signingError } = await supabase.storage
    .from(audioAsset.storage_bucket)
    .createSignedUrl(audioAsset.storage_path, SIGNED_URL_TTL_SECONDS);

  if (signingError || !signed?.signedUrl) {
    console.error("MAC READS audio signing failed", signingError);
    return Response.json({ error: "Audio is temporarily unavailable." }, { status: 503 });
  }

  return Response.redirect(signed.signedUrl, 307);
}
