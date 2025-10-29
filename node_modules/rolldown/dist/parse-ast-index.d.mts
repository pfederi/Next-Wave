import { ParseResult, ParserOptions } from "./shared/binding-9k0egz6L.mjs";
import { Program } from "@oxc-project/types";

//#region src/parse-ast-index.d.ts
declare function parseAst(sourceText: string, options?: ParserOptions | undefined | null, filename?: string): Program;
declare function parseAstAsync(sourceText: string, options?: ParserOptions | undefined | null, filename?: string): Promise<Program>;
//#endregion
export { type ParseResult, type ParserOptions, parseAst, parseAstAsync };