import React from 'react';
import NavLogo from "./components/NavLogo";
import { DocsThemeConfig } from 'nextra-theme-docs';

const config: DocsThemeConfig = {
  logo: NavLogo,
  project: {
    link: 'https://github.com/tenetxyz/biomes-scaffold',
  },
  chat: {
    link: 'https://discord.gg/J75hkmtmM4',
  },
  docsRepositoryBase: 'https://github.com/tenetxyz/biomes-scaffold',
  footer: {
    text: 'BIOMES EXPERIENCES',
  },
}

export default config
