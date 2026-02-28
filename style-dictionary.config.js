module.exports = {
  source: [
    'tokens/src/core/global.json',
    'tokens/src/core/alias.json',
    'tokens/src/core/components/*.json'
  ],
  // Transitional config: retained for AC-TKN-009/015 while build-tokens.sh
  // remains the canonical generator in this repository.
  transforms: {
    'color/modify-primary-dark': {
      type: 'value',
      matcher: (token) => token.path && token.path.join('.') === 'color.primaryDark',
      transformer: () => '#8c002f',
      modify: { mode: 'darken', amount: 10 }
    }
  },
  platforms: {
    css: {
      transformGroup: 'css',
      buildPath: 'infrastructure/tutor/themes/mereka/mfe/theme/',
      files: [
        {
          destination: 'mereka-brand.min.css',
          format: 'css/variables'
        }
      ]
    }
  }
};
