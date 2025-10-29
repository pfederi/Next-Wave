import { BindingAssetPluginConfig, BindingBuildImportAnalysisPluginConfig, BindingDynamicImportVarsPluginConfig, BindingEsmExternalRequirePluginConfig, BindingHmrUpdate, BindingImportGlobPluginConfig, BindingIsolatedDeclarationPluginConfig, BindingJsonPluginConfig, BindingManifestPluginConfig, BindingModulePreloadPolyfillPluginConfig, BindingReplacePluginConfig, BindingReporterPluginConfig, BindingTransformPluginConfig, BindingViteResolvePluginConfig, BindingWasmHelperPluginConfig, IsolatedDeclarationsOptions, IsolatedDeclarationsResult, NapiResolveOptions, ResolveResult, ResolverFactory, TransformOptions, TransformResult, isolatedDeclaration, moduleRunnerTransform, transform } from "./shared/binding-9k0egz6L.mjs";
import { BuiltinPlugin, InputOptions, OutputOptions, StringOrRegExp, defineParallelPlugin } from "./shared/define-config-3arq8OPE.mjs";

//#region src/api/dev/dev-options.d.ts
interface DevOptions {
  onHmrUpdates?: (updates: BindingHmrUpdate[]) => void | Promise<void>;
  usePolling?: boolean;
  pollInterval?: number;
}
//#endregion
//#region src/api/dev/dev-engine.d.ts
declare class DevEngine {
  #private;
  static create(inputOptions: InputOptions, outputOptions?: OutputOptions, devOptions?: DevOptions): Promise<DevEngine>;
  private constructor();
  run(): Promise<void>;
  ensureCurrentBuildFinish(): Promise<void>;
  ensureLatestBuild(): Promise<void>;
  invalidate(file: string, firstInvalidatedBy?: string): Promise<BindingHmrUpdate>;
}
//#endregion
//#region src/api/dev/index.d.ts
declare var dev: typeof DevEngine.create;
//#endregion
//#region src/api/experimental.d.ts
/**
* This is an experimental API. It's behavior may change in the future.
*
* Calling this API will only execute the scan stage of rolldown.
*/
declare const experimental_scan: (input: InputOptions) => Promise<void>;
//#endregion
//#region src/builtin-plugin/constructors.d.ts
declare function modulePreloadPolyfillPlugin(config?: BindingModulePreloadPolyfillPluginConfig): BuiltinPlugin;
type DynamicImportVarsPluginConfig = Omit<BindingDynamicImportVarsPluginConfig, "include" | "exclude"> & {
  include?: StringOrRegExp | StringOrRegExp[];
  exclude?: StringOrRegExp | StringOrRegExp[];
};
declare function dynamicImportVarsPlugin(config?: DynamicImportVarsPluginConfig): BuiltinPlugin;
declare function importGlobPlugin(config?: BindingImportGlobPluginConfig): BuiltinPlugin;
declare function reporterPlugin(config?: BindingReporterPluginConfig): BuiltinPlugin;
declare function manifestPlugin(config?: BindingManifestPluginConfig): BuiltinPlugin;
declare function wasmHelperPlugin(config?: BindingWasmHelperPluginConfig): BuiltinPlugin;
declare function wasmFallbackPlugin(): BuiltinPlugin;
declare function loadFallbackPlugin(): BuiltinPlugin;
declare function jsonPlugin(config?: BindingJsonPluginConfig): BuiltinPlugin;
declare function buildImportAnalysisPlugin(config: BindingBuildImportAnalysisPluginConfig): BuiltinPlugin;
declare function viteResolvePlugin(config: BindingViteResolvePluginConfig): BuiltinPlugin;
declare function isolatedDeclarationPlugin(config?: BindingIsolatedDeclarationPluginConfig): BuiltinPlugin;
declare function assetPlugin(config?: BindingAssetPluginConfig): BuiltinPlugin;
declare function webWorkerPostPlugin(): BuiltinPlugin;
declare function esmExternalRequirePlugin(config?: BindingEsmExternalRequirePluginConfig): BuiltinPlugin;
//#endregion
//#region src/builtin-plugin/alias-plugin.d.ts
type AliasPluginAlias = {
  find: string | RegExp;
  replacement: string;
};
type AliasPluginConfig = {
  entries: AliasPluginAlias[];
};
declare function aliasPlugin(config: AliasPluginConfig): BuiltinPlugin;
//#endregion
//#region src/builtin-plugin/replace-plugin.d.ts
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
declare function replacePlugin(values?: BindingReplacePluginConfig["values"], options?: Omit<BindingReplacePluginConfig, "values">): BuiltinPlugin;
//#endregion
//#region src/builtin-plugin/transform-plugin.d.ts
type TransformPattern = string | RegExp | readonly (RegExp | string)[];
type TransformPluginConfig = Omit<BindingTransformPluginConfig, "include" | "exclude" | "jsxRefreshInclude" | "jsxRefreshExclude"> & {
  include?: TransformPattern;
  exclude?: TransformPattern;
  jsxRefreshInclude?: TransformPattern;
  jsxRefreshExclude?: TransformPattern;
};
declare function transformPlugin(config?: TransformPluginConfig): BuiltinPlugin;
//#endregion
export { DevEngine, type DevOptions, type IsolatedDeclarationsOptions, type IsolatedDeclarationsResult, type NapiResolveOptions as ResolveOptions, type ResolveResult, ResolverFactory, type TransformOptions, type TransformResult, aliasPlugin, assetPlugin, buildImportAnalysisPlugin, defineParallelPlugin, dev, dynamicImportVarsPlugin, esmExternalRequirePlugin, importGlobPlugin, isolatedDeclaration, isolatedDeclarationPlugin, jsonPlugin, loadFallbackPlugin, manifestPlugin, modulePreloadPolyfillPlugin, moduleRunnerTransform, replacePlugin, reporterPlugin, experimental_scan as scan, transform, transformPlugin, viteResolvePlugin, wasmFallbackPlugin, wasmHelperPlugin, webWorkerPostPlugin };