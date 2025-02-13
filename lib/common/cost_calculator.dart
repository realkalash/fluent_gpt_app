
class CostCalculator {
  /* 
  https://help.openai.com/en/articles/7127956-how-much-does-gpt-4-cost

  For our models with 128k context lengths (e.g. gpt-4-turbo), the price is:

$10.00 / 1 million prompt tokens (or $0.01 / 1K prompt tokens)

$30.00 / 1 million sampled tokens (or $0.03 / 1K sampled tokens)

 For our models with 8k context lengths (e.g. gpt-4 and gpt-4-0314), the price is:

$30.00 / 1 million prompt token (or $0.03 / 1K prompt tokens)

$60.00 / 1 million sampled tokens (or $0.06 / 1K sampled tokens)

For our models with 32k context lengths (e.g. gpt-4-32k and gpt-4-32k-0314), the price is:

$60.00 / 1 million prompt tokens (or $0.06 / 1K prompt tokens)

$120.00 / 1 million sampled tokens (or $0.12 / 1K sampled tokens)

GPT-3.5 Turbo models are capable and cost-effective.
gpt-3.5-turbo-0125 is the flagship model of this family, supports a 16K context
 */

  @Deprecated('Not used anymore')
  static final pricePerThousendPromptToken = {
    'gpt-4o': 0.015,
    'gpt-4-0125-preview': 0.03,
    'gpt-4-turbo': 0.03,
    'gpt-4': 0.06,
    'gpt-3.5-turbo': 0.0015,
    'gpt-3.5-turbo-instruct': 0.0020,
  };

  static double calculateCostPer1MToken(int tokens, int pricePer1M) {
    return tokens * (pricePer1M / 1_000_000); 
  }

  static double calculateCostPer1KToken(int tokens, int pricePer1M) {
    return tokens * (pricePer1M / 1_000_000) / 1_000;
  }
}
