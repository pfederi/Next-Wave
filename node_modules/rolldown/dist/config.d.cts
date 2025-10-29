import "./shared/binding-D13M6Llu.cjs";
import { ConfigExport, defineConfig } from "./shared/define-config-DhrkZ_o7.cjs";

//#region src/utils/load-config.d.ts
declare function loadConfig(configPath: string): Promise<ConfigExport>;
//#endregion
//#region src/config.d.ts
declare const VERSION: string;
//#endregion
export { VERSION, defineConfig, loadConfig };