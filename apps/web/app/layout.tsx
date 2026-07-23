import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'PAWD — find your pet a friend',
  description:
    'A pet-centric social platform: find nearby pets for playdates, walks and companionship.',
  manifest: '/manifest.webmanifest',
};

export const viewport: Viewport = {
  themeColor: '#ff6b3d',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="shell">{children}</div>
      </body>
    </html>
  );
}
