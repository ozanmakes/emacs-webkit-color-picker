import path from "path";

import alias from "rollup-plugin-alias";
import babel from "rollup-plugin-babel";
import cjs from "rollup-plugin-commonjs";
import globals from "rollup-plugin-node-globals";
import replace from "rollup-plugin-replace";
import resolve from "rollup-plugin-node-resolve";
import uglify from "rollup-plugin-uglify";
import browsersync from "rollup-plugin-browsersync";

const production = !process.env.ROLLUP_WATCH;

const devPlugins = !production ? [browsersync({ server: "build" })] : [];
const prodPlugins = production ? [uglify()] : [];

export default {
  input: "src/index.js",
  output: {
    name: "colorpicker",
    file: production ? "build/app.min.js" : "build/app.js",
    format: "iife",
    sourcemap: true
  },
  plugins: [
    alias({
      react: path.resolve(
        __dirname,
        "node_modules",
        "preact-compat",
        "dist",
        "preact-compat.es.js"
      ),
      "react-dom": path.resolve(
        __dirname,
        "node_modules",
        "preact-compat",
        "dist",
        "preact-compat.es.js"
      ),
      "create-react-class": path.resolve(
        __dirname,
        "node_modules",
        "preact-compat",
        "lib",
        "create-react-class.js"
      )
    }),
    resolve({
      browser: true,
      main: true
    }),
    cjs({
      exclude: ["node_modules/process-es6/**", "node_modules/react-color/**"],
      include: [
        "node_modules/fbjs/**",
        "node_modules/object-assign/**",
        "node_modules/reactcss/**",
        "node_modules/lodash/**",
        "node_modules/tinycolor2/**",
        "node_modules/prop-types/**"
      ],
      namedExports: {
        "node_modules/react/index.js": [
          "Component",
          "PureComponent",
          "Children",
          "createElement"
        ]
      }
    }),
    globals(),
    replace({
      "process.env.NODE_ENV": JSON.stringify(
        production ? "production" : "development"
      )
    }),
    babel({
      babelrc: false,
      presets: [
        [
          "env",
          {
            modules: false,
            loose: true
            // targets: { safari: 11 }
          }
        ],
        "stage-0",
        "react"
      ],
      plugins: ["external-helpers"]
    }),
    ...devPlugins,
    ...prodPlugins
  ]
};
