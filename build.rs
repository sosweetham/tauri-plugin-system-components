const COMMANDS: &[&str] = &[
    "configure_tab_bar",
    "remove_tab_bar",
    "show_tab_bar",
    "hide_tab_bar",
    "select_tab",
    "set_badge",
    "get_tab_bar_insets",
    "create_component",
    "update_component",
    "update_components",
    "remove_component",
    "is_glass_supported",
    "set_window_glass",
    "clear_window_glass",
    // Required for addPluginListener() — the JS side invokes
    // plugin:liquid-glass|register_listener to receive `trigger`ed events,
    // and remove_listener when the returned PluginListener unregisters.
    "register_listener",
    "remove_listener",
];

fn main() {
    tauri_plugin::Builder::new(COMMANDS).ios_path("ios").build();
}
