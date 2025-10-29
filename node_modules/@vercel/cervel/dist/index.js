import { createRequire } from "module";
import { existsSync } from "fs";
import { readFile, rm, writeFile } from "fs/promises";
import { extname, join, relative } from "path";
import { build as build$1 } from "rolldown";
import { spawn } from "child_process";
import execa from "execa";

//#region src/utils.ts
const noColor = globalThis.process?.env?.NO_COLOR === "1" || globalThis.process?.env?.TERM === "dumb";
const resets = {
	1: 22,
	31: 39,
	32: 39,
	33: 39,
	34: 39,
	35: 39,
	36: 39,
	90: 39
};
const _c = (c) => (text) => {
	if (noColor) return text;
	return `\u001B[${c}m${text}\u001B[${resets[c] ?? 0}m`;
};
const Colors = {
	bold: _c(1),
	red: _c(31),
	green: _c(32),
	yellow: _c(33),
	blue: _c(34),
	magenta: _c(35),
	cyan: _c(36),
	gray: _c(90),
	url: (title, url) => noColor ? `[${title}](${url})` : `\u001B]8;;${url}\u001B\\${title}\u001B]8;;\u001B\\`
};

//#endregion
//#region src/typescript.ts
const require_ = createRequire(import.meta.url);
const typescript = async (args) => {
	const extension = extname(args.entrypoint);
	if (![
		".ts",
		".mts",
		".cts"
	].includes(extension)) return;
	const tscPath = resolveTscPath(args);
	if (!tscPath) {
		console.log(Colors.gray(`${Colors.bold(Colors.cyan("✓"))} Typecheck skipped ${Colors.gray("(TypeScript not found)")}`));
		return Promise.resolve();
	}
	return doTypeCheck(args, tscPath);
};
async function doTypeCheck(args, tscPath) {
	let stdout = "";
	let stderr = "";
	/**
	* This might be subject to change.
	* - if no tscPath, skip typecheck
	* - if tsconfig, provide the tsconfig path
	* - else provide the entrypoint path
	*/
	const tscArgs = [
		tscPath,
		"--noEmit",
		"--pretty",
		"--allowJs",
		"--esModuleInterop",
		"--skipLibCheck"
	];
	const tsconfig = await findNearestTsconfig(args.workPath);
	if (tsconfig) tscArgs.push("--project", tsconfig);
	else tscArgs.push(args.entrypoint);
	const child = spawn(process.execPath, tscArgs, {
		cwd: args.workPath,
		stdio: [
			"ignore",
			"pipe",
			"pipe"
		]
	});
	child.stdout?.on("data", (data) => {
		stdout += data.toString();
	});
	child.stderr?.on("data", (data) => {
		stderr += data.toString();
	});
	await new Promise((resolve, reject) => {
		child.on("close", (code) => {
			if (code === 0) {
				console.log(Colors.gray(`${Colors.bold(Colors.cyan("✓"))} Typecheck complete`));
				resolve();
			} else {
				const output = stdout || stderr;
				if (output) {
					console.error("\nTypeScript type check failed:\n");
					console.error(output);
				}
				reject(/* @__PURE__ */ new Error("TypeScript type check failed"));
			}
		});
		child.on("error", (err) => {
			reject(err);
		});
	});
}
const resolveTscPath = (args) => {
	try {
		return require_.resolve("typescript/bin/tsc", { paths: [args.workPath] });
	} catch (e) {
		return null;
	}
};
const findNearestTsconfig = async (workPath) => {
	const tsconfigPath = join(workPath, "tsconfig.json");
	if (existsSync(tsconfigPath)) return tsconfigPath;
	if (workPath === "/") return;
	return findNearestTsconfig(join(workPath, ".."));
};

//#endregion
//#region src/rolldown.ts
const rolldown = async (args) => {
	const baseDir = args.repoRootPath || args.workPath;
	const entrypointPath = join(args.workPath, args.entrypoint);
	const shouldAddSourcemapSupport = false;
	const extension = extname(args.entrypoint);
	const extensionMap = {
		".ts": {
			format: "auto",
			extension: "js"
		},
		".mts": {
			format: "esm",
			extension: "mjs"
		},
		".cts": {
			format: "cjs",
			extension: "cjs"
		},
		".cjs": {
			format: "cjs",
			extension: "cjs"
		},
		".js": {
			format: "auto",
			extension: "js"
		},
		".mjs": {
			format: "esm",
			extension: "mjs"
		}
	};
	let format = (extensionMap[extension] || extensionMap[".js"]).format;
	const packageJsonPath = join(args.workPath, "package.json");
	const external = [];
	let pkg = {};
	if (existsSync(packageJsonPath)) {
		const source = await readFile(packageJsonPath, "utf8");
		try {
			pkg = JSON.parse(source.toString());
		} catch (_e) {
			pkg = {};
		}
		if (format === "auto") if (pkg.type === "module") format = "esm";
		else format = "cjs";
		for (const dependency of Object.keys(pkg.dependencies || {})) external.push(dependency);
		for (const dependency of Object.keys(pkg.devDependencies || {})) external.push(dependency);
		for (const dependency of Object.keys(pkg.peerDependencies || {})) external.push(dependency);
		for (const dependency of Object.keys(pkg.optionalDependencies || {})) external.push(dependency);
	}
	const absoluteImportPlugin = {
		name: "absolute-import-resolver",
		resolveId(source) {
			if (external.includes(source)) return {
				id: source,
				external: true
			};
			return null;
		}
	};
	const tsconfig = await findNearestTsconfig(baseDir);
	const relativeOutputDir = args.out;
	const outputDir = join(baseDir, relativeOutputDir);
	let handler = null;
	await build$1({
		input: entrypointPath,
		cwd: baseDir,
		platform: "node",
		external: /node_modules/,
		plugins: [absoluteImportPlugin],
		tsconfig,
		output: {
			dir: outputDir,
			entryFileNames: (info) => {
				if (info.name === "rolldown_runtime") return "rolldown_runtime.js";
				const facadeModuleId = info.facadeModuleId;
				if (!facadeModuleId) throw new Error(`Unable to resolve module for ${info.name}`);
				const relPath = relative(baseDir, facadeModuleId);
				const extension$1 = extname(relPath);
				const ext = {
					".ts": ".js",
					".mts": ".mjs",
					".mjs": ".mjs",
					".cts": ".cjs",
					".cjs": ".cjs",
					".js": ".js"
				}[extension$1] || ".js";
				const nameWithJS = relPath.slice(0, -extension$1.length) + ext;
				if (info.isEntry) handler = nameWithJS;
				return nameWithJS;
			},
			format,
			preserveModules: true,
			sourcemap: false
		}
	});
	if (typeof handler !== "string") throw new Error(`Unable to resolve module for ${args.entrypoint}`);
	const cleanup = async () => {
		await rm(outputDir, {
			recursive: true,
			force: true
		});
	};
	return {
		result: {
			pkg,
			shouldAddSourcemapSupport,
			handler,
			outputDir
		},
		cleanup
	};
};

//#endregion
//#region src/find-entrypoint.ts
const frameworks = ["express", "hono"];
const entrypointFilenames = [
	"app",
	"index",
	"server"
];
const entrypointExtensions = [
	"js",
	"cjs",
	"mjs",
	"ts",
	"cts",
	"mts"
];
const entrypoints = entrypointFilenames.flatMap((filename) => entrypointExtensions.map((extension) => `${filename}.${extension}`));
const createFrameworkRegex = (framework) => new RegExp(`(?:from|require|import)\\s*(?:\\(\\s*)?["']${framework}["']\\s*(?:\\))?`, "g");
const findEntrypoint = async (cwd, options) => {
	if (options?.ignoreRegex ?? false) {
		for (const entrypoint of entrypoints) if (existsSync(join(cwd, entrypoint))) return entrypoint;
		for (const entrypoint of entrypoints) if (existsSync(join(cwd, "src", entrypoint))) return join("src", entrypoint);
		throw new Error("No entrypoint file found");
	}
	const packageJson = await readFile(join(cwd, "package.json"), "utf-8");
	const packageJsonObject = JSON.parse(packageJson);
	const framework = frameworks.find((framework$1) => packageJsonObject.dependencies?.[framework$1]);
	if (!framework) throw new Error("No framework found in package.json");
	const regex = createFrameworkRegex(framework);
	for (const entrypoint of entrypoints) {
		const entrypointPath = join(cwd, entrypoint);
		try {
			const content = await readFile(entrypointPath, "utf-8");
			if (regex.test(content)) return entrypoint;
		} catch (e) {
			continue;
		}
	}
	for (const entrypoint of entrypoints) {
		const entrypointPath = join(cwd, "src", entrypoint);
		try {
			const content = await readFile(entrypointPath, "utf-8");
			if (regex.test(content)) return join("src", entrypoint);
		} catch (e) {
			continue;
		}
	}
	throw new Error("No entrypoint found");
};

//#endregion
//#region src/index.ts
const require = createRequire(import.meta.url);
const getBuildSummary = async (outputDir) => {
	const buildSummary = await readFile(join(outputDir, ".cervel.json"), "utf-8");
	return JSON.parse(buildSummary);
};
const build = async (args) => {
	const entrypoint = args.entrypoint || await findEntrypoint(args.cwd);
	const rolldownResult = await rolldown({
		...args,
		entrypoint,
		workPath: args.cwd,
		repoRootPath: args.cwd,
		out: args.out
	});
	await writeFile(join(args.cwd, args.out, ".cervel.json"), JSON.stringify({ handler: rolldownResult.result.handler }, null, 2));
	const tsPromise = typescript({
		...args,
		entrypoint,
		workPath: args.cwd
	});
	console.log(Colors.gray(`${Colors.bold(Colors.cyan("✓"))} Build complete`));
	return {
		rolldownResult: rolldownResult.result,
		tsPromise
	};
};
const serve = async (args) => {
	const entrypoint = await findEntrypoint(args.cwd);
	const srvxBin = join(require.resolve("srvx"), "..", "..", "..", "bin", "srvx.mjs");
	const tsxBin = require.resolve("tsx");
	const restArgs = Object.entries(args.rest).filter(([, value]) => value !== void 0 && value !== false).map(([key, value]) => typeof value === "boolean" ? `--${key}` : `--${key}=${value}`);
	if (!args.rest.import) restArgs.push("--import", tsxBin);
	await execa("npx", [
		srvxBin,
		...restArgs,
		entrypoint
	], {
		cwd: args.cwd,
		stdio: "inherit"
	});
};
const srvxOptions = {
	help: {
		type: "boolean",
		short: "h"
	},
	version: {
		type: "boolean",
		short: "v"
	},
	prod: { type: "boolean" },
	port: {
		type: "string",
		short: "p"
	},
	host: {
		type: "string",
		short: "H"
	},
	static: {
		type: "string",
		short: "s"
	},
	import: { type: "string" },
	tls: { type: "boolean" },
	cert: { type: "string" },
	key: { type: "string" }
};

//#endregion
export { build, findEntrypoint, getBuildSummary, serve, srvxOptions };