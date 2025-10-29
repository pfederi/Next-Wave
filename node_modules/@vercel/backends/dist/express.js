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
//#region src/introspection/express.ts
let app = null;
const handle = (expressModule) => {
	if (typeof expressModule === "function") {
		const originalCreateApp = expressModule;
		const createApp = (...args) => {
			app = originalCreateApp(...args);
			return app;
		};
		Object.setPrototypeOf(createApp, originalCreateApp);
		Object.assign(createApp, originalCreateApp);
		return createApp;
	}
	return expressModule;
};
setupCloseHandlers(() => {
	const routes = extractRoutes();
	if (routes.length > 0) return {
		frameworkSlug: "express",
		routes
	};
});
const extractRoutes = () => {
	if (!app) return [];
	const routes = [];
	const methods = [
		"all",
		"get",
		"post",
		"put",
		"delete",
		"patch",
		"options",
		"head"
	];
	const router = app._router || app.router;
	for (const route of router.stack) if (route.route) {
		const m = [];
		for (const method of methods) if (route.route.methods[method]) m.push(method.toUpperCase());
		const { regexp } = pathToRegexp(route.route.path);
		if (route.route.path === "/") continue;
		routes.push({
			src: regexp.source,
			dest: route.route.path,
			methods: m
		});
	}
	return routes;
};

//#endregion
export { handle };