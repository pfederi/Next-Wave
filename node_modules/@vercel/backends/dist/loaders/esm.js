import { register } from "node:module";

//#region src/introspection/loaders/esm.ts
register(new URL("./hooks.js", import.meta.url), import.meta.url);

//#endregion
export {  };