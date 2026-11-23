pragma solidity 0.8.17;

enum HookType {
    DEPOSIT_HOOK,
    WITHDRAW_HOOK,
    OPEN_REBALANCE_HOOK,
    CLOSE_REBALANCE_HOOK
}

interface IHookExecutor {
    function executeHook(HookType _type, bytes calldata _data) external returns (bytes memory);
}
