import { BuildV2 } from "@vercel/build-utils";

//#region src/index.d.ts
declare const version = 2;
declare const build: BuildV2;
//#endregion
export { build, version };