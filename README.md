# Agitate

Advanced Git and GitHub abstractions for Neovim.

## Features

Agitate provides a few "api" functions that you can
call from the command line or keybindings.
They are all prefixed with `:Agitate` and grouped by **_context_**.

Every agitate command starts with `:Agitate` and is followed by the
context and the action. Example:

```vim
:AgitateRepoCreate
```

### Available contexts

- **Repo**: Actions that affect the repository as a whole.
- **Branch**: Actions that affect the branches of the repository.
- **Pr**: Actions on the pull requests of the repository.

You can easily verify what the commands are and what they do by looking at the
[files in the `api` directory](./lua/agitate/api). But here's a quick overview:

#### Repo

- `:AgitateRepoCreate` - Create a new remote repository on GitHub.  
  Uses the repository name provided as an optional argument **_or_** the current
  directory as the repository name if no argument is provided.

- `:AgitateRepoInit` - Initializes the current directory as a GitHub
  repository.  
  Uses the repository name provided as an optional argument **_or_** the current
  directory as the repository name if no argument is provided.
  This command basically does what GitHub tells you to do to contribute to a
  newly created repository.

#### Pr

Like the issue commands, these work out the repository from the `origin`
remote. `-u` and `-r` override the owner and repository anywhere below.

- `:AgitatePrCreate` - Open a new pull request.  
  Takes `-H` for the head branch and `-B` for the base. Head defaults to the
  current branch and base to the repository's default branch.  
  Opens a scratch buffer: the first line is the title, the rest is the body.

- `:AgitatePrList` - List the pull requests. Takes `-s` for the state.  
  In the list: `<CR>` views, `o` opens in the browser, `c` comments, `m` merges
  and `q` quits.

- `:AgitatePrView` - View a pull request and its comments. Takes `-n`.

- `:AgitatePrComment` - Comment on a pull request. Takes `-n`.

- `:AgitatePrMerge` - Merge a pull request.  
  Takes `-n` and `-m` for the method (`merge`, `squash` or `rebase`,
  defaulting to `merge`).  
  Refuses when GitHub reports the pull request as unmergeable, and asks for
  confirmation before merging.

#### Branch

- `:AgitateBranchCreateCheckoutAndPush` - Create a new branch from the current
  one, checkout to it and push it to the remote repository.  
  Requires the branch name as an argument.

## Usage

You can use the commands directly from the command line, but it is recommended
to bind them to a keybinding to be able to use `Agitate` with less friction.

vimscript:

```vim
nnoremap <leader>gil :AgitateRepoInit
nnoremap <leader>gir :AgitateRepoCreate
nnoremap <leader>gbp :AgitateBranchCreateCheckoutAndPush
```

lua:

```lua
vim.keymap.set('n', '<leader>gil', ':AgitateRepoInit ')
vim.keymap.set('n', '<leader>gir', ':AgitateRepoCreate ')
vim.keymap.set('n', '<leader>gbp', ':AgitateBranchCreateCheckoutAndPush ')
```

**Note**: It is recommended to **_NOT_** include `<CR>` (Enter key) in the command
keybinding, and also to leave a single trailing space after the command so you can
easily provide the arguments when using the keybinding. The trailing whitespace is
ignored if you don't provide any arguments, you can just press enter.

## Installation

> Agitate assumes you already use tpope's [vim-fugitive](github.com/tpope/vim-fugitive).
> If you don't, you should install it as well.

Install using your favorite package manager, for example [lazy](github.com/folke/lazy.nvim):

```lua
use {
  'paulo-granthon/agitate.nvim',
  config = function()
    require('agitate').setup({
      github_username = '<make sure to set this>',
      github_access_token = '<make sure to set this>',

      -- your configuration here
    })
  end,
}
```

## Configuration

In order to communicate with the GitHub API and effectively use Agitate, you need
to provide your GitHub username and an access token. The **Repo** commands only
work with GitHub repositories for now and require both the username (to figure out
the URL of the repo) and the access token (to authenticate with the GitHub API).

Currently, Agitate supports the following options with the following defaults:

```lua
require('agitate').setup({
  github_username = nil, -- replace with your github username
  github_access_token = nil, -- replace with your github access token

  repo = { -- Repository configuration
    init = { -- Initializing repositories context
      show_status = false, -- show the status of the repository after initializing it
      first_commit_message = 'first commit', -- message to use when initializing locally
    },
  },
}

```

## 📝 todo!()

Features planned for implementation

- [ ] Branch functions:

  - [x] Create a new branch from the current one, checkout to it and push it to remote.
  - [ ] Delete a branch both locally and from the remote repository.

- [ ] Repository functions:

  - [x] Initialize a local repository.
    - [x] Initialize a repository with explicit name parameter
    - [x] Initialize an Organization repository

  - [x] Create a new remote repository on GitHub.
    - [x] Create repository with explicit name parameter
    - [x] Create Organization repository.
    - [x] Create private repository

  - [ ] Add visibility function (change repo public / private)

- [ ] File generation functions:
  - [ ] Add `.gitiginore` from github template
  - [ ] Add `LICENSE` from github template

  - [ ] Add `FUNDING.yml`
  - [ ] Add `MAINTAINERS.md` (?)

- [x] Issues & PRs:
  - [x] Open, list, view, comment on, close and reopen issues.
  - [x] Open, list, view, comment on and merge pull requests.

- [ ] Project functions:
  - Blocked. The classic Projects REST API has been sunset and Projects V2 is
    reachable only through GraphQL, so this needs a GraphQL client alongside
    the REST one and a token carrying the `project` scope. Worth revisiting
    once the REST backed features have landed.

## Contributing

Contributions are welcome! Feel free to open an issue or a pull request.

## License

This project is licensed under the MIT License -
see the [LICENSE](./LICENSE) file for details.
