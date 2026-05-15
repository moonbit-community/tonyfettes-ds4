///|
test "backend helpers" {
  let backend = Backend::default()
  assert_true(backend.name() == "metal" || backend.name() == "cuda")
  assert_true(ThinkMode::high().enabled())
  assert_false(ThinkMode::none().enabled())
}

///|
test "tokens container" {
  let tokens = Tokens::new()
  tokens.push(7)
  tokens.push(11)
  assert_true(tokens.length() == 2)
  assert_true(tokens[0] == 7)
  assert_true(tokens.get(2) == None)
  let copied = tokens.copy()
  assert_true(copied.starts_with(tokens))
  assert_true(tokens.to_fixed_array().length() == 2)
}
