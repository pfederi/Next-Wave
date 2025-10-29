import "./shared/binding-9k0egz6L.mjs";
import { ConfigExport, defineConfig } from "./shared/define-config-3arq8OPE.mjs";

//#region src/utils/load-config.d.ts
declare function loadConfig(configPath: string): Promise<ConfigExport>;
//#endregion
//#region src/config.d.ts
declare const VERSION: string;
//#endregion
export { VERSION, defineConfig, loadConfig };