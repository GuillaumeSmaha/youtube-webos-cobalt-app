const path = require('path');
const CopyPlugin = require('copy-webpack-plugin');

const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = (env) => [
  {
    mode: env.production ? 'production' : 'development',

    target: 'browserslist',

    // Builds with devtool support (development) contain very big eval chunks,
    // which seem to cause segfaults (at least) on nodeJS v0.12.2 used on webOS 3.x.
    // This feature makes sense only when using recent enough chrome-based
    // node inspector anyway.
    devtool: env.production ? false : 'source-map',

    optimization: {
      minimize: env.production ? true : false,
    },

    entry: {
      index: './src/index.js',
      adblockMain: './src/userScript.js',
      userScript: './src/userScript.js'
    },
    output: {
      path: path.resolve(__dirname, './dist'),
      filename: ({ chunk: { name } }) =>
        name === 'userScript' ? 'webOSUserScripts/[name].js' : '[name].js'
    },
    resolve: {
      extensions: ['.ts', '.js']
    },
    module: {
      rules: [
        {
          test: /\.m?js$/,
          loader: 'babel-loader',
          exclude: [
            // Some module should not be transpiled by Babel
            // See https://github.com/zloirock/core-js/issues/743#issuecomment-572074215
            // \\ for Windows, / for macOS and Linux
            /node_modules[\\/]core-js/,
            /node_modules[\\/]webpack[\\/]buildin/
          ],
          options: {
            cacheDirectory: true
          }
        },
        {
          test: /\.css$/i,
          use: [
            MiniCssExtractPlugin.loader,
            { loader: 'css-loader', options: { esModule: false } }
          ]
        }
      ]
    },
    plugins: [
      new MiniCssExtractPlugin({
        chunkFilename: '[id].css'
      }),
      new CopyPlugin({
        patterns: [
          { context: 'assets', from: '**/*' },
          { context: 'src', from: 'index.html' }
        ]
      })
    ]
  }
];
