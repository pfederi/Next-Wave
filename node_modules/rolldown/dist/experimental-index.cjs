const require_chunk = require('./shared/chunk-DDkG_k5U.cjs');
const require_parse_ast_index = require('./shared/parse-ast-index-cePJvlvW.cjs');
const require_src = require('./shared/src-BBMxhaqf.cjs');
require('./shared/misc-DksvspN4.cjs');
let node_url = require("node:url");
node_url = require_chunk.__toESM(node_url);

//#region src/api/dev/dev-engine.ts
var DevEngine = class DevEngine {
	#inner;
	#cachedBuildFinishPromise = null;
	static async create(inputOptions, outputOptions = {}, devOptions = {}) {
		inputOptions = await require_src.PluginDriver.callOptionsHook(inputOptions);
		const options = await require_src.createBundlerOptions(inputOptions, outputOptions, false);
		const bindingDevOptions = {
			onHmrUpdates: devOptions.onHmrUpdates,
			usePolling: devOptions.usePolling,
			pollInterval: devOptions.pollInterval
		};
		const inner = new require_parse_ast_index.BindingDevEngine(options.bundlerOptions, bindingDevOptions);
		return new DevEngine(inner);
	}
	constructor(inner) {
		this.#inner = inner;
	}
	async run() {
		await this.#inner.run();
	}
	async ensureCurrentBuildFinish() {
		if (this.#cachedBuildFinishPromise) return this.#cachedBuildFinishPromise;
		const promise = this.#inner.ensureCurrentBuildFinish().then(() => {
			this.#cachedBuildFinishPromise = null;
		});
		this.#cachedBuildFinishPromise = promise;
		return promise;
	}
	async ensureLatestBuild() {
		await this.#inner.ensureLatestBuild();
	}
	async invalidate(file, firstInvalidatedBy) {
		return this.#inner.invalidate(file, firstInvalidatedBy);
	}
};

//#endregion
//#region src/api/dev/index.ts
var dev = DevEngine.create;

//#endregion
//#region src/api/experimental.ts
/**
* This is an experimental API. It's behavior may change in the future.
*
* Calling this API will only execute the scan stage of rolldown.
*/
const experimental_scan = async (input) => {
	const inputOptions = await require_src.PluginDriver.callOptionsHook(input);
	const { impl: bundler, stopWorkers } = await require_src.createBundlerImpl(new require_parse_ast_index.BindingBundler(), inputOptions, {});
	const output = await bundler.scan();
	require_src.handleOutputErrors(output);
	await stopWorkers?.();
};

//#endregion
//#region src/plugin/parallel-plugin.ts
function defineParallelPlugin(pluginPath) {
	return (options) => {
		return { _parallel: {
			fileUrl: (0, node_url.pathToFileURL)(pluginPath).href,
			options
		} };
	};
}

//#endregion
//#region src/builtin-plugin/alias-plugin.ts
function aliasPlugin(config) {
	return require_src.createBuiltinPlugin("builtin:alias", config);
}

//#endregion
//#region src/builtin-plugin/replace-plugin.ts
/**
* Replaces targeted strings in files while bundling.
*
* @example
* // Basic usage
* ```js
* replacePlugin({
*   'process.env.NODE_ENV': JSON.stringify('production'),
*    __buildVersion: 15
* })
* ```
* @example
* // With options
* ```js
* replacePlugin({
*   'process.env.NODE_ENV': JSON.stringify('production'),
*   __buildVersion: 15
* }, {
*   preventAssignment: false,
* })
* ```
*/
function replacePlugin(values = {}, options = {}) {
	Object.keys(values).forEach((key) => {
		values[key] = values[key].toString();
	});
	return require_src.createBuiltinPlugin("builtin:replace", {
		...options,
		values
	});
}

//#endregion
//#region src/builtin-plugin/transform-plugin.ts
function transformPlugin(config) {
	if (config) config = {
		...config,
		include: require_src.normalizedStringOrRegex(config.include),
		exclude: require_src.normalizedStringOrRegex(config.exclude),
		jsxRefreshInclude: require_src.normalizedStringOrRegex(config.jsxRefreshInclude),
		jsxRefreshExclude: require_src.normalizedStringOrRegex(config.jsxRefreshExclude)
	};
	return require_src.createBuiltinPlugin("builtin:transform", config);
}

//#endregion
exports.DevEngine = DevEngine;
exports.ResolverFactory = require_parse_ast_index.ResolverFactory;
exports.aliasPlugin = aliasPlugin;
exports.assetPlugin = require_src.assetPlugin;
exports.buildImportAnalysisPlugin = require_src.buildImportAnalysisPlugin;
exports.defineParallelPlugin = defineParallelPlugin;
exports.dev = dev;
exports.dynamicImportVarsPlugin = require_src.dynamicImportVarsPlugin;
exports.esmExternalRequirePlugin = require_src.esmExternalRequirePlugin;
exports.importGlobPlugin = require_src.importGlobPlugin;
exports.isolatedDeclaration = require_parse_ast_index.isolatedDeclaration;
exports.isolatedDeclarationPlugin = require_src.isolatedDeclarationPlugin;
exports.jsonPlugin = require_src.jsonPlugin;
exports.loadFallbackPlugin = require_src.loadFallbackPlugin;
exports.manifestPlugin = require_src.manifestPlugin;
exports.modulePreloadPolyfillPlugin = require_src.modulePreloadPolyfillPlugin;
exports.moduleRunnerTransform = require_parse_ast_index.moduleRunnerTransform;
exports.replacePlugin = replacePlugin;
exports.reporterPlugin = require_src.reporterPlugin;
exports.scan = experimental_scan;
exports.transform = require_parse_ast_index.transform;
exports.transformPlugin = transformPlugin;
exports.viteResolvePlugin = require_src.viteResolvePlugin;
exports.wasmFallbackPlugin = require_src.wasmFallbackPlugin;
exports.wasmHelperPlugin = require_src.wasmHelperPlugin;
exports.webWorkerPostPlugin = require_src.webWorkerPostPlugin;