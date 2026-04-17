function Invoke-ModelAdapter {
  param(
    [string]$Prompt
  )

  $provider = $env:CG_MODEL_PROVIDER

  switch ($provider) {

    "openai" {
      # call OpenAI API
    }

    "local" {
      # call local model (ollama, etc.)
    }

    "mock" {
      return "mock response"
    }

    default {
      throw "UNKNOWN_MODEL_PROVIDER"
    }
  }
}
