import { createRequire } from 'node:module';
import { parse, resolve, dirname, join, basename } from 'node:path';
import process from 'node:process';
import { t as toArray } from './shared/unconfig.p5vR8nLf.mjs';
import { stat, lstat, readFile, writeFile, unlink } from '@quansync/fs';
import defu from 'defu';
import { quansync } from 'quansync/macro';

const isFile = quansync(function* (path, allowSymlinks) {
  try {
    return (yield (allowSymlinks ? stat : lstat)(path)).isFile();
  } catch {
    return false;
  }
});
const findUp = quansync(
  function* (paths, options = {}) {
    const {
      cwd = process.cwd(),
      stopAt = parse(cwd).root,
      multiple = false,
      allowSymlinks = true
    } = options;
    let current = cwd;
    const files = [];
    while (current && current !== stopAt) {
      for (const path of paths) {
        const filepath = resolve(current, path);
        if (yield isFile(filepath, allowSymlinks)) {
          files.push(filepath);
          if (!multiple)
            return files;
        }
      }
      const parent = dirname(current);
      if (parent === current)
        break;
      current = parent;
    }
    return files;
  }
);

function interopDefault(mod) {
  if (mod == null || typeof mod !== "object" || !("default" in mod) || mod.default == null)
    return mod;
  const defaultValue = mod.default;
  if (typeof defaultValue !== "object")
    return defaultValue;
  for (const key in mod) {
    try {
      if (!(key in defaultValue)) {
        Object.defineProperty(defaultValue, key, {
          enumerable: key !== "default",
          configurable: key !== "default",
          get() {
            return mod[key];
          }
        });
      }
    } catch {
    }
  }
  return defaultValue;
}

const defaultExtensions = ["mts", "cts", "ts", "mjs", "cjs", "js", "json", ""];

const require = createRequire(import.meta.url);
const loadConfigFile = quansync(function* (filepath, source) {
  let config;
  let parser = source.parser || "auto";
  let bundleFilepath = filepath;
  let code;
  let dependencies;
  const read = quansync(function* () {
    if (code == null)
      code = yield readFile(filepath, "utf8");
    return code;
  });
  const importModule = quansync({
    sync: () => {
      const { createJiti } = require("jiti");
      const jiti = createJiti(import.meta.url, {
        fsCache: false,
        moduleCache: false,
        interopDefault: true
      });
      config = interopDefault(jiti(bundleFilepath));
      dependencies = Object.values(jiti.cache).map((i) => i.filename).filter(Boolean);
    },
    async: async () => {
      const { createJiti } = await import('jiti');
      const jiti = createJiti(import.meta.url, {
        fsCache: false,
        moduleCache: false,
        interopDefault: true
      });
      config = interopDefault(await jiti.import(bundleFilepath, { default: true }));
      dependencies = Object.values(jiti.cache).map((i) => i.filename).filter(Boolean);
    }
  });
  if (source.transform) {
    const transformed = yield source.transform(yield read(), filepath);
    if (transformed) {
      bundleFilepath = join(dirname(filepath), `__unconfig_${basename(filepath)}`);
      yield writeFile(bundleFilepath, transformed, "utf8");
      code = transformed;
    }
  }
  if (parser === "auto") {
    try {
      config = JSON.parse(yield read());
      parser = "json";
    } catch {
      parser = "import";
    }
  }
  try {
    if (!config) {
      if (typeof parser === "function") {
        config = yield parser(filepath);
      } else if (parser === "import") {
        yield importModule();
      } else if (parser === "json") {
        config = JSON.parse(yield read());
      }
    }
    if (!config)
      return;
    const rewritten = source.rewrite ? yield source.rewrite(config, filepath) : config;
    if (!rewritten)
      return void 0;
    return {
      config: rewritten,
      sources: [filepath],
      dependencies
    };
  } catch (e) {
    if (source.skipOnError)
      return;
    throw e;
  } finally {
    if (bundleFilepath !== filepath) {
      try {
        yield unlink(bundleFilepath);
      } catch {
      }
    }
  }
});
function createConfigLoader(options) {
  const sources = toArray(options.sources || []);
  const {
    cwd = process.cwd(),
    merge,
    defaults
  } = options;
  const results = [];
  let matchedFiles;
  const findConfigs = quansync(function* () {
    if (matchedFiles == null)
      matchedFiles = [];
    matchedFiles.length = 0;
    for (const source of sources) {
      const { extensions = defaultExtensions } = source;
      const flatTargets = toArray(source?.files || []).flatMap(
        (file) => !extensions.length ? [file] : extensions.map((i) => i ? `${file}.${i}` : file)
      );
      const files = yield findUp(flatTargets, { cwd, stopAt: options.stopAt, multiple: merge });
      matchedFiles.push([source, files]);
    }
    return matchedFiles.flatMap((i) => i[1]);
  });
  const load = quansync(function* (force = false) {
    if (matchedFiles == null || force)
      yield findConfigs();
    for (const [source, files] of matchedFiles) {
      if (!files.length)
        continue;
      if (!merge) {
        const result = yield loadConfigFile(files[0], source);
        if (result) {
          return {
            config: applyDefaults(result.config, defaults),
            sources: result.sources,
            dependencies: result.dependencies
          };
        }
      } else {
        for (const file of files) {
          const result = yield loadConfigFile(file, source);
          if (result) {
            results.push(result);
          }
        }
      }
    }
    if (!results.length) {
      return {
        config: defaults,
        sources: []
      };
    }
    return {
      config: applyDefaults(...results.map((i) => i.config), defaults),
      sources: results.map((i) => i.sources).flat(),
      dependencies: results.flatMap((i) => i.dependencies || [])
    };
  });
  return {
    load,
    findConfigs
  };
}
function applyDefaults(...args) {
  return defu(...args.map((i) => ({ config: i }))).config;
}
const loadConfig = quansync(
  function* (options) {
    return createConfigLoader(options).load();
  }
);
const loadConfigSync = loadConfig.sync;

export { createConfigLoader, defaultExtensions, loadConfig, loadConfigSync };
