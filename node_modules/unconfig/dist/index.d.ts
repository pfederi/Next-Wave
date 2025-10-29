import * as quansync_types from 'quansync/types';
import { QuansyncAwaitableGenerator } from 'quansync';
import { L as LoadConfigOptions, a as LoadConfigResult } from './shared/unconfig.Bryl7mAo.js';
export { B as BuiltinParsers, C as CustomParser, b as LoadConfigSource, S as SearchOptions, d as defaultExtensions } from './shared/unconfig.Bryl7mAo.js';

declare function createConfigLoader<T>(options: LoadConfigOptions): {
    load: quansync_types.QuansyncFn<LoadConfigResult<T>, [force?: Args[0] | undefined]>;
    findConfigs: quansync_types.QuansyncFn<string[], []>;
};
declare const loadConfig: {
    <T>(options: LoadConfigOptions<T>): QuansyncAwaitableGenerator<LoadConfigResult<T>>;
    sync: <T>(options: LoadConfigOptions<T>) => LoadConfigResult<T>;
    async: <T>(options: LoadConfigOptions<T>) => Promise<LoadConfigResult<T>>;
};
declare const loadConfigSync: <T>(options: LoadConfigOptions<T>) => LoadConfigResult<T>;

export { LoadConfigOptions, LoadConfigResult, createConfigLoader, loadConfig, loadConfigSync };
