import { A as Arrayable, b as LoadConfigSource, B as BuiltinParsers, C as CustomParser } from './shared/unconfig.Bryl7mAo.js';

interface SourceVitePluginConfigOptions {
    plugins: Arrayable<string>;
    /**
     * Parameters that passed to when the default export is a function
     */
    parameters?: any[];
}
interface SourceObjectFieldOptions extends Omit<LoadConfigSource, 'rewrite'> {
    fields: Arrayable<string>;
    /**
     * Parameters that passed to when the default export is a function
     */
    parameters?: any[];
}
interface SourcePluginFactoryOptions extends Omit<LoadConfigSource, 'transform'> {
    targetModule: string;
    /**
     * Parameters that passed to when the default export is a function
     */
    parameters?: any[];
}
/**
 * Rewrite the config file and extract the options passed to plugin factory
 * (e.g. Vite and Rollup plugins)
 */
declare function sourcePluginFactory(options: SourcePluginFactoryOptions): {
    transform: (source: string) => string;
    targetModule: string;
    /**
     * Parameters that passed to when the default export is a function
     */
    parameters?: any[];
    files: Arrayable<string>;
    extensions?: string[] | undefined;
    parser?: BuiltinParsers | "auto" | CustomParser<any> | undefined;
    rewrite?: (<F = any>(obj: F, filepath: string) => any) | undefined;
    skipOnError?: boolean | undefined;
};
declare function sourceVitePluginConfig(options: SourceVitePluginConfigOptions): LoadConfigSource;
/**
 * Get one field of the config object
 */
declare function sourceObjectFields(options: SourceObjectFieldOptions): LoadConfigSource;
/**
 * Get one field of `package.json`
 */
declare function sourcePackageJsonFields(options: Pick<SourceObjectFieldOptions, 'fields'>): LoadConfigSource;

export { sourceObjectFields, sourcePackageJsonFields, sourcePluginFactory, sourceVitePluginConfig };
export type { SourceObjectFieldOptions, SourcePluginFactoryOptions, SourceVitePluginConfigOptions };
