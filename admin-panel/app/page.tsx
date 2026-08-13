import Link from 'next/link';

const cards = [
  ['Total users', '0'],
  ['Total teams', '0'],
  ['Registrations', '0'],
  ['Active tournaments', '0'],
];

export default function Dashboard() {
  return (
    <main className="min-h-screen bg-[radial-gradient(circle_at_top_left,rgba(138,92,255,0.24),transparent_32%),linear-gradient(180deg,#07101f_0%,#0b1328_55%,#050814_100%)] px-6 py-10 text-white">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 flex flex-col gap-4 rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl md:flex-row md:items-center md:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.35em] text-cyan-300">ArenaHub Admin</p>
            <h1 className="mt-2 text-3xl font-black tracking-tight md:text-5xl">Tournament control room</h1>
            <p className="mt-2 max-w-2xl text-sm text-white/70 md:text-base">
              Manage users, tournaments, registrations, and platform settings from one esports-first dashboard.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              href="/dashboard"
              className="rounded-full border border-white/15 bg-white/8 px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/12"
            >
              Open Dashboard
            </Link>
            <Link
              href="/tournaments/new"
              className="rounded-full bg-linear-to-r from-violet-500 to-cyan-400 px-5 py-3 text-sm font-semibold text-white shadow-lg shadow-violet-500/25 transition hover:opacity-95"
            >
              Create Tournament
            </Link>
          </div>
        </header>

        <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {cards.map(([label, value]) => (
            <article
              key={label}
              className="rounded-3xl border border-white/10 bg-white/5 p-5 shadow-xl shadow-black/20 backdrop-blur-md"
            >
              <p className="text-sm text-white/60">{label}</p>
              <h2 className="mt-3 text-4xl font-black tracking-tight text-white">{value}</h2>
              <div className="mt-5 h-1.5 rounded-full bg-white/10">
                <div className="h-1.5 w-1/3 rounded-full bg-linear-to-r from-violet-500 to-cyan-400" />
              </div>
            </article>
          ))}
        </section>

        <section className="mt-8 grid gap-6 lg:grid-cols-[1.3fr_0.7fr]">
          <article className="rounded-[28px] border border-white/10 bg-[#0b1226]/90 p-6 shadow-2xl shadow-black/30">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.3em] text-cyan-300">Live ops</p>
                <h2 className="mt-2 text-2xl font-bold">Registration policy</h2>
              </div>
              <span className="rounded-full border border-emerald-400/30 bg-emerald-400/10 px-3 py-1 text-xs font-semibold text-emerald-300">
                Ready for production
              </span>
            </div>
            <p className="mt-4 max-w-2xl text-sm leading-6 text-white/70">
              Choose whether tournaments use individual player ads or captain ads. Changes are applied only to new registrations so historical tournaments remain stable.
            </p>
            <div className="mt-6 grid gap-4 md:grid-cols-2">
              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-sm text-white/60">Tournament flow</p>
                <p className="mt-2 text-lg font-semibold text-white">Published, open, and slot-safe</p>
              </div>
              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-sm text-white/60">Reward integrity</p>
                <p className="mt-2 text-lg font-semibold text-white">SSV-backed ad verification</p>
              </div>
            </div>
          </article>

          <aside className="rounded-[1.75rem] border border-white/10 bg-linear-to-br from-violet-500/15 to-cyan-400/10 p-6 shadow-2xl shadow-black/20">
            <p className="text-xs uppercase tracking-[0.3em] text-white/60">Quick actions</p>
            <div className="mt-4 space-y-3">
              <Link href="/users" className="block rounded-2xl border border-white/10 bg-white/6 px-4 py-3 font-semibold text-white transition hover:bg-white/10">
                Manage users
              </Link>
              <Link href="/registrations" className="block rounded-2xl border border-white/10 bg-white/6 px-4 py-3 font-semibold text-white transition hover:bg-white/10">
                Review registrations
              </Link>
              <Link href="/settings" className="block rounded-2xl border border-white/10 bg-white/6 px-4 py-3 font-semibold text-white transition hover:bg-white/10">
                Platform settings
              </Link>
            </div>
          </aside>
        </section>
      </div>
    </main>
  );
}
