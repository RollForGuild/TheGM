defmodule Thegm.ErrorView do
  @moduledoc "View for API errors"
  use Thegm.Web, :view

  def render("404.json", _assigns) do
    %{errors: %{detail: "Page not found"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal server error"}}
  end

  def render("error.json", %{errors: errors}) do
    %{
        meta: %{count: length(errors)},
        errors: Enum.map(errors, &error_json/1)
    }
  end

  def error_json(error) do
    %{
        detail: error
    }
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.json", assigns
  end
end
