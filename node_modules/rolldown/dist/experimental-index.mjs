import { BindingBundler, BindingDevEngine, ResolverFactory, isolatedDeclaration, moduleRunnerTransform, transform } from "./shared/parse-ast-index-BadydpMA.mjs";
import { PluginDriver, assetPlugin, buildImportAnalysisPlugin, createBuiltinPlugin, createBundlerImpl, createBundlerOptions, dynamicImportVarsPlugin, esmExternalRequirePlugin, handleOutputErrors, importGlobPlugin, isolatedDeclarationPlugin, jsonPlugin, loadFallbackPlugin, manifestPlugin, modulePreloadPolyfillPlugin, normalizedStringOrRegex, reporterPlugin, viteResolvePlugin, wasmFallbackPlugin, wasmHelperPlugin, webWorkerPostPlugin } from "./shared/src-D954P1TH.mjs";
import "./shared/misc-CQeo-AFx.mjs";
import { pathToFileURL } from "node:url";

//#region src/api/dev/dev-engine.ts
var DevEngine = class DevEngine {
	#inner;
	#cachedBuildFinishPromise = null;
	static async create(inputOptions, outputOptions = {}, devOptions = {}) {
		inputOptions = await PluginDriver.callOptionsHook(inputOptions);
		const options = await createBundlerOptions(inputOptions, outputOptions, false);
		const bindingDevOptions = {
			onHmrUpdates: devOptions.onHmrUpdates,
			usePolling: devOptions.usePolling,
			pollInterval: devOptions.pollInterval
		};
		const inner = new BindingDevEngine(options.bundlerOptions, bindingDevOptions);
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
	const inputOptions = await PluginDriver.callOptionsHook(input);
	const { impl: bundler, stopWorkers } = await createBundlerImpl(new BindingBundler(), inputOptions, {});
	const output = await bundler.scan();
	handleOutputErrors(output);
	await stopWorkers?.();
};

//#endregion
//#region src/plugin/parallel-plugin.ts
function defineParallelPlugin(pluginPath) {
	return (options) => {
		return { _parallel: {
			fileUrl: pathToFileURL(pluginPath).href,
			options
		} };
	};
}

//#endregion
//#region src/builtin-plugin/alias-plugin.ts
function aliasPlugin(config) {
	return createBuiltinPlugin("builtin:alias", config);
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
	return createBuiltinPlugin("builtin:replace", {
		...options,
		values
	});
}

//#endregion
//#region src/builtin-plugin/transform-plugin.ts
function transformPlugin(config) {
	if (config) config = {
		...config,
		include: normalizedStringOrRegex(config.include),
		exclude: normalizedStringOrRegex(config.exclude),
		jsxRefreshInclude: normalizedStringOrRegex(config.jsxRefreshInclude),
		jsxRefreshExclude: normalizedStringOrRegex(config.jsxRefreshExclude)
	};
	return createBuiltinPlugin("builtin:transform", config);
}

//#endregion
export { DevEngine, ResolverFactory, aliasPlugin, assetPlugin, buildImportAnalysisPlugin, defineParallelPlugin, dev, dynamicImportVarsPlugin, esmExternalRequirePlugin, importGlobPlugin, isolatedDeclaration, isolatedDeclarationPlugin, jsonPlugin, loadFallbackPlugin, manifestPlugin, modulePreloadPolyfillPlugin, moduleRunnerTransform, replacePlugin, reporterPlugin, experimental_scan as scan, transform, transformPlugin, viteResolvePlugin, wasmFallbackPlugin, wasmHelperPlugin, webWorkerPostPlugin };