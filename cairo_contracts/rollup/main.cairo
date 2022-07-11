struct PublicOutput:
    member global_config_code : felt  # why do we need this?
    member initial_rollup_state_root : felt
    member final_rollup_state_root : felt
    member global_expiration_timestamp : felt
    member rollup_state_tree_height : felt
    member n_swaps : felt
    # member n_l1_vault_updates : felt
    # member n_l1_order_messages : felt
end
