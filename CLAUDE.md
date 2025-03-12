# ProtoRune Development Guidelines

## Build/Lint/Test Commands
- Install dependencies: `mix deps.get`
- Build: `mix compile`
- Format code: `mix format`
- Run all tests: `mix test`
- Run specific test: `mix test path/to/test.exs:line_number`
- Lint code: `mix credo`
- Type checking: `mix dialyxir`

## Code Style Guidelines
- Follow standard Elixir conventions with snake_case for variables and functions
- All public functions require @spec typespecs and documentation with @doc/@moduledoc
- 100% type coverage is expected; functions should be focused and small
- Error handling through ProtoRune.XRPC.Error with appropriate reason atoms
- Use ProtoRune.Case for camelCase/snake_case conversions between Elixir and AT Protocol
- Format code before committing with `mix format` (using styler 1.3)
- Follow consistent module organization pattern in lib/ directory structure
- Use existing patterns and frameworks when adding new components
- When implementing callbacks, follow existing implementation patterns
