/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'vaeiskltcpzthaffyejg.supabase.co' },
    ],
  },
};

export default nextConfig;
