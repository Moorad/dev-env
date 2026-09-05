import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	let clearScreen: (() => void) | undefined;

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Capture the TUI without adding anything visible to the layout. Pi's first
		// three root containers are the header, startup details, and chat transcript.
		ctx.ui.setWidget("vim-commands-tui", (tui) => {
			const clearableContainers = tui.children.slice(0, 3) as Array<{ clear(): void }>;
			clearScreen = () => {
				for (const container of clearableContainers) container.clear();
				tui.requestRender(true);
			};
			return {
				render: () => [],
				invalidate: () => {},
			};
		});
	});

	pi.registerCommand("clear", {
		description: "Clear displayed history, terminal screen, and scrollback",
		handler: async (_args, ctx) => {
			if (ctx.mode === "tui" && clearScreen) {
				clearScreen();
			}
		},
	});

	pi.on("input", (event, ctx) => {
		const input = event.text.trim();

		if (input === ":q") {
			ctx.shutdown();
			return { action: "handled" };
		}

		if (input === ":clear") {
			if (ctx.mode === "tui" && clearScreen) {
				clearScreen();
			}
			return { action: "handled" };
		}

		return { action: "continue" };
	});
}
