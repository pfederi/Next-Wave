import { pathToRegexp } from "path-to-regexp";

//#region src/introspection/util.ts
const setupCloseHandlers = (cb) => {
	const callCallback = () => {
		const result = cb();
		if (result) console.log(JSON.stringify(result));
	};
	process.on("SIGINT", callCallback);
	process.on("SIGTERM", callCallback);
	process.on("exit", callCallback);
};

//#endregion
//#region src/introspection/hono.ts
const apps = [];
const handle = (honoModule) => {
	const TrackedHono = class extends honoModule.Hono {
		constructor(...args) {
			super(...args);
			apps.push(this);
		}
	};
	return TrackedHono;
};
setupCloseHandlers(() => {
	const routes = extractRoutes();
	if (routes.length > 0) return {
		frameworkSlug: "hono",
		routes
	};
});
function extractRoutes() {
	const app = apps.sort((a, b) => b.routes.length - a.routes.length)[0];
	if (!app || !app.routes) return [];
	const routes = [];
	for (const route of app.routes) {
		const routePath = route.path;
		const method = route.method.toUpperCase();
		const { regexp } = pathToRegexp(routePath);
		if (routePath === "/") continue;
		routes.push({
			src: regexp.source,
			dest: routePath,
			methods: [method]
		});
	}
	return routes;
}

//#endregion
export { handle };