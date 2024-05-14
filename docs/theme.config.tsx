import React from 'react';
import NavLogo from "./components/NavLogo";
import { DocsThemeConfig } from 'nextra-theme-docs';
import { useRouter } from 'next/router';

const config: DocsThemeConfig = {
  logo: NavLogo,
  useNextSeoProps() {
    const { asPath } = useRouter();
    return {
      titleTemplate: asPath === "/" ? "Biomes Experiences Docs" : "%s - Biomes",
    };
  },
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
