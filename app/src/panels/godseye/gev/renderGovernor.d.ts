export function installRenderGovernor(viewer: unknown): void;
export function holdContinuousRender(ownerId: string): void;
export function releaseContinuousRender(ownerId: string): void;
export function governorRequestRender(reason?: string): void;
export function getRenderGovernorDiagnostics(): unknown;
export function uninstallRenderGovernor(viewer: unknown): void;
export function _resetRenderGovernorForTest(): void;
