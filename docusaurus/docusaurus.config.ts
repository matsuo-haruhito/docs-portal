import type {Config} from '@docusaurus/types';

const config: Config = {
  title: 'External Document Site',
  url: 'https://example.invalid',
  baseUrl: '/',
  presets: [
    [
      'classic',
      {
        docs: {
          path: process.env.DOCUSAURUS_DOCS_PATH ?? '../docs-src',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          lastVersion: 'current',
          editUrl: process.env.DOCUSAURUS_EDIT_URL,
        },
        blog: false,
        pages: false,
      },
    ],
  ],

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  markdown: {
    hooks: {
      onBrokenMarkdownImages: 'warn',
    },
  },
};

export default config;
