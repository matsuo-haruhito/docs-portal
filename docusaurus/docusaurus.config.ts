import type {Config} from '@docusaurus/types';
import remarkKrokiDiagrams from './plugins/remark-kroki-diagrams.mjs';

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
          remarkPlugins: [[remarkKrokiDiagrams, {}]],
        },
        blog: false,
        pages: false,
      },
    ],
  ],

  onBrokenLinks: 'warn',

  themes: ['@docusaurus/theme-mermaid'],

  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
      onBrokenMarkdownImages: 'warn',
    },
  },
};

export default config;
