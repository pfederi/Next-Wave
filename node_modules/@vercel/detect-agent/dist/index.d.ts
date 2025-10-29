declare const CURSOR: "cursor";
declare const CURSOR_CLI: "cursor-cli";
declare const CLAUDE: "claude";
declare const DEVIN: "devin";
declare const REPLIT: "replit";
declare const GEMINI: "gemini";
declare const CODEX: "codex";
export type KnownAgentNames = typeof CURSOR | typeof CURSOR_CLI | typeof CLAUDE | typeof DEVIN | typeof REPLIT | typeof GEMINI | typeof CODEX;
export interface KnownAgentDetails {
    name: KnownAgentNames;
}
export type AgentResult = {
    isAgent: true;
    agent: KnownAgentDetails;
} | {
    isAgent: false;
    agent: undefined;
};
export declare const KNOWN_AGENTS: {
    readonly CURSOR: "cursor";
    readonly CURSOR_CLI: "cursor-cli";
    readonly CLAUDE: "claude";
    readonly DEVIN: "devin";
    readonly REPLIT: "replit";
    readonly GEMINI: "gemini";
    readonly CODEX: "codex";
};
export declare function determineAgent(): Promise<AgentResult>;
export {};
