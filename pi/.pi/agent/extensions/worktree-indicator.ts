import { watch, type FSWatcher } from "node:fs";
import { basename, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

const WIDGET_KEY = "git-worktree-indicator";

type WorktreeInfo = {
	name: string;
	ref: string;
	detached: boolean;
	gitDir: string;
};

export default function worktreeIndicator(pi: ExtensionAPI) {
	let watcher: FSWatcher | undefined;
	let refreshTimer: NodeJS.Timeout | undefined;
	let requestRender: (() => void) | undefined;
	let info: WorktreeInfo | undefined;
	let generation = 0;

	const stop = () => {
		generation++;
		if (refreshTimer) {
			clearTimeout(refreshTimer);
			refreshTimer = undefined;
		}
		watcher?.close();
		watcher = undefined;
		requestRender = undefined;
		info = undefined;
	};

	const git = async (cwd: string, args: string[]) => {
		try {
			const result = await pi.exec("git", args, { cwd, timeout: 2000 });
			return result.code === 0 ? result.stdout.trim() : undefined;
		} catch {
			return undefined;
		}
	};

	const readRef = async (cwd: string): Promise<Pick<WorktreeInfo, "ref" | "detached"> | undefined> => {
		const branch = await git(cwd, ["symbolic-ref", "--quiet", "--short", "HEAD"]);
		if (branch) return { ref: branch, detached: false };

		const commit = await git(cwd, ["rev-parse", "--short", "HEAD"]);
		return commit ? { ref: commit, detached: true } : undefined;
	};

	const discover = async (cwd: string): Promise<WorktreeInfo | undefined> => {
		const topLevel = await git(cwd, ["rev-parse", "--show-toplevel"]);
		if (!topLevel) return undefined;

		const gitDir = await git(cwd, ["rev-parse", "--absolute-git-dir"]);
		if (!gitDir) return undefined;

		const ref = await readRef(cwd);
		if (!ref) return undefined;

		return {
			name: basename(topLevel),
			gitDir,
			...ref,
		};
	};

	pi.on("session_start", async (_event, ctx) => {
		stop();
		ctx.ui.setWidget(WIDGET_KEY, undefined);
		if (ctx.mode !== "tui") return;

		const currentGeneration = generation;
		const discovered = await discover(ctx.cwd);
		if (currentGeneration !== generation || !discovered) return;
		info = discovered;

		ctx.ui.setWidget(WIDGET_KEY, (tui, theme) => {
			requestRender = () => tui.requestRender();
			return {
				render(width: number): string[] {
					if (!info || width <= 0) return [];

					const worktree = theme.fg("accent", info.name);
					const ref = info.detached
						? theme.fg("warning", `detached @ ${info.ref}`)
						: theme.fg("success", info.ref);
					const line = `${theme.fg("dim", "worktree: ")}${worktree}${theme.fg("dim", "  branch: ")}${ref}`;
					return [truncateToWidth(line, width)];
				},
				invalidate() {},
			};
		});

		const refresh = async () => {
			const ref = await readRef(ctx.cwd);
			if (currentGeneration !== generation || !ref || !info) return;
			if (info.ref === ref.ref && info.detached === ref.detached) return;
			info = { ...info, ...ref };
			requestRender?.();
		};

		try {
			const headWatcher = watch(discovered.gitDir, (_event, filename) => {
				if (currentGeneration !== generation) return;
				if (filename && filename.toString() !== "HEAD") return;
				if (refreshTimer) clearTimeout(refreshTimer);
				refreshTimer = setTimeout(() => {
					refreshTimer = undefined;
					void refresh();
				}, 50);
			});
			watcher = headWatcher;
			headWatcher.on("error", () => {
				headWatcher.close();
				if (watcher === headWatcher) watcher = undefined;
			});
		} catch {
			// The indicator remains useful even if this filesystem cannot be watched.
		}
	});

	pi.on("session_shutdown", (_event, ctx) => {
		stop();
		ctx.ui.setWidget(WIDGET_KEY, undefined);
	});
}
