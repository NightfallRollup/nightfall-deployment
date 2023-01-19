module.exports = {
  extends: ['eslint:recommended', 'plugin:prettier/recommended'],
  rules: {
    'no-underscore-dangle': 'off',
    'no-console': 'off',
    'import/extensions': 'off',
    'no-restricted-syntax': 'off',
    'no-plusplus': 'off',
    'func-names': 'off',
  },
  parser: 'babel-eslint', // Uses babel-eslint transforms.
  parserOptions: {
    ecmaVersion: 2018, // Allows for the parsing of modern ECMAScript features
    sourceType: 'module', // Allows for the use of imports
  },
  env: {
    mocha: true,
    browser: true,
    node: true,
    jest: true,
  },
  plugins: ['import'],
};
