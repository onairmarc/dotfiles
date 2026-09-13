import type {TuiPluginModule, TuiPromptRef} from "@opencode-ai/plugin/tui";
import {registerFilePickerCommands} from "../lib/file-picker-commands";

const plugin: TuiPluginModule = {
    id: "custom",
    tui: async (api) => {
        let prompt: TuiPromptRef | undefined;
        const Prompt = api.ui.Prompt;
        const capturePrompt = (value: TuiPromptRef | undefined, ref?: (ref: TuiPromptRef | undefined) => void): void => {
            prompt = value;
            ref?.(value);
        };

        api.slots.register({
            slots: {
                home_prompt(_context, props) {
                    return <Prompt ref={(value) => capturePrompt(value, props.ref)}/>;
                },
                session_prompt(_context, props) {
                    return (
                        <Prompt
                        sessionID={props.session_id}
                        visible={props.visible}
                        disabled={props.disabled}
                        onSubmit={props.on_submit}
                        ref={(value) => capturePrompt(value, props.ref)}
                        />
                    );
                },
            },
        });

        registerFilePickerCommands(api, () => prompt);
    },
};

export default plugin;