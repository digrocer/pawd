'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const items = [
  { href: '/discover', label: 'Discover', icon: 'M12 3l9 7-1.5 1.5L18 10v9H6v-9l-1.5 1.5L3 10z' },
  { href: '/matches', label: 'Matches', icon: 'M12 21s-7-4.35-9.5-8.5C.9 9.7 2.4 6 6 6c2 0 3.2 1.2 4 2.3C10.8 7.2 12 6 14 6c3.6 0 5.1 3.7 3.5 6.5C19 16.65 12 21 12 21z' },
  { href: '/pets', label: 'My Pets', icon: 'M4.5 9a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zm15 0a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM9 6.5A2.5 2.5 0 1 0 9 1.5a2.5 2.5 0 0 0 0 5zm6 0a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM12 12c-3 0-6 2.5-6 5.5 0 1.7 1.3 3 3 3 1.2 0 2-.7 3-.7s1.8.7 3 .7c1.7 0 3-1.3 3-3 0-3-3-5.5-6-5.5z' },
  { href: '/profile', label: 'Profile', icon: 'M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2c-4.4 0-8 2.7-8 6v1h16v-1c0-3.3-3.6-6-8-6z' },
];

export default function BottomNav() {
  const path = usePathname();
  return (
    <nav className="bottom-nav">
      {items.map((it) => {
        const active = path === it.href || path.startsWith(it.href + '/');
        return (
          <Link key={it.href} href={it.href} className={active ? 'active' : ''}>
            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden>
              <path d={it.icon} />
            </svg>
            {it.label}
          </Link>
        );
      })}
    </nav>
  );
}
