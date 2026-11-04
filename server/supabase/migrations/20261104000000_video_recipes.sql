-- Videodan çıkarılan tariflerin ortak önbelleği: bir video bir kez yapay
-- zekadan geçer, sonra herkes buradan alır. Kişisel veri tutulmaz (kimin
-- paylaştığı kaydedilmez), yalnızca herkese açık video adresi ve tarif.
create table if not exists public.video_recipes (
  video_key   text primary key,          -- "tiktok:<video kimliği>"
  url         text not null,
  recipe      jsonb not null,            -- uygulamanın Recipe JSON biçimi
  unmatched   jsonb not null default '[]'::jsonb,
  source      text not null check (source in ('caption', 'transcript')),
  hits        integer not null default 0,
  created_at  timestamptz not null default now()
);

-- Tabloya yalnızca Edge Function (service role) erişir; uygulama doğrudan okumaz.
alter table public.video_recipes enable row level security;

create or replace function public.bump_video_recipe_hits(p_key text)
returns void language sql security definer set search_path = public as $$
  update public.video_recipes set hits = hits + 1 where video_key = p_key;
$$;
revoke all on function public.bump_video_recipe_hits(text) from public, anon, authenticated;
