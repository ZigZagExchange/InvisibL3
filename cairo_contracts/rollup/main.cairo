struct PublicOutput:
    member global_config_code : felt  # why do we need this?
    member init_state_root : felt
    member final_state_root : felt
    member tree_depth : felt
    member global_expiration_timestamp : felt
    member n_swaps : felt
    member n_deposits : felt
    member n_withdrawals : felt
end
