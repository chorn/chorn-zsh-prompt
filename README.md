# chorn-zsh-prompt
This is my async zsh prompt

# install

The key is adding the prompt to your zsh `FPATH`

Assuming you have `$HOME/.config/zsh/site-functions` in your `FPATH`:

- locally clone this repo somewhere accessible
- also clone [zsh async](https://github.com/mafredri/zsh-async)
- make `zsh-async/async.zsh` executable
- make `chorn-zsh-prompt/chorn-prompt.zsh` executable
- soft link `chorn-prompt.zsh` to `$HOME/.config/zsh/site-functions/prompt_chorn_setup`
- soft link `zsh-async/async.zsh` to `$HOME/.config/zsh/site-functions/async`
- run `autoload -U promptinit` and `promptinit`
- run `prompt chorn`
