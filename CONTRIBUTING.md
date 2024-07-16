# Contributing to FluentGPT

First off, thank you for considering contributing to FluentGPT! It's people like you that make FluentGPT such a great tool.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct. Please report unacceptable behavior to 1realkalash@gmail.com.

## Getting Started

Contributions to FluentGPT are made via Issues and Pull Requests (PRs). A few general guidelines that cover both:

- Search for existing Issues and PRs before creating your own.
- We work hard to make sure issues are handled in a timely manner but, depending on the impact, it could take a while to investigate the root cause. A friendly ping in the comment thread to the submitter or a contributor can help draw attention if your issue is blocking.

### Issues

Issues should be used to report problems with the library, request a new feature, or to discuss potential changes before a PR is created. When you create a new Issue, a template will be loaded that will guide you through collecting and providing the information we need to investigate.

If you find an Issue that addresses the problem you're having, please add your own reproduction information to the existing issue rather than creating a new one. Adding a [reaction](https://github.blog/2016-03-10-add-reactions-to-pull-requests-issues-and-comments/) can also help by indicating to our maintainers that a particular problem is affecting more than just the reporter.

### Pull Requests

PRs to our libraries are always welcome and can be a quick way to get your fix or improvement slated for the next release. In general, PRs should:

- Only fix/add the functionality in question OR address wide-spread whitespace/style issues, not both.
- Add unit or integration tests for fixed or changed functionality (if a test suite already exists).
- Address a single concern in the least number of changed lines as possible.
- Include documentation in the repo
- Be accompanied by a complete Pull Request template (loaded automatically when a PR is created).

For changes that address core functionality or would require breaking changes (e.g. a major release), it's best to open an Issue to discuss your proposal first. This is not required but can save time creating and reviewing changes.

## Git Workflow

We use a centralized workflow in our repository to streamline contributions and avoid unnecessary forks. Here are the steps to contribute:

1. Clone the main repository to your local machine:
   ```
   git clone https://github.com/username/FluentGPT.git
   ```

2. Create a new branch for your feature or fix. Use a descriptive name that summarizes your contribution:
   ```
   git checkout -b feature/your-feature-name
   ```
   or
   ```
   git checkout -b fix/issue-you-are-fixing
   ```

3. Make your changes in this branch. Commit your changes with clear, concise commit messages:
   ```
   git commit -m "Add feature: brief description of your feature"
   ```

4. Push your branch to the main repository:
   ```
   git push -u origin feature/your-feature-name
   ```

5. Open a Pull Request (PR) from your branch to the main branch of the repository.

6. Wait for review. Make any requested changes by adding new commits to your branch.

7. Once approved, your PR will be merged into the main branch.

Important notes:
- Always create a new branch for each feature or fix. Don't reuse branches for multiple unrelated changes.
- Keep your branches up to date with the main branch:
  ```
  git checkout main
  git pull
  git checkout your-feature-branch
  git merge main
  ```
- If you don't have write access to the main repository, you may need to fork it first. However, we encourage you to request write access if you plan to contribute regularly.

Remember, every change, no matter how small, should go through a pull request. This ensures code review and maintains code quality.

## Getting Help

Join us in the [Github discussions](https://github.com/realkalash/fluent_gpt_app/discussions) for general help or discussion.
