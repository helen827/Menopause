import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { App } from "./App";


describe("App", () => {
  beforeEach(() => window.history.replaceState({}, "", "/"));
  afterEach(() => {
    cleanup();
    window.history.replaceState({}, "", "/");
  });

  it("renders the trend dashboard by default", () => {
    render(<App />);
    expect(screen.getByRole("heading", { name: "身体趋势" })).toBeInTheDocument();
    expect(screen.getByText("医疗提示")).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "主导航" })).toBeInTheDocument();
  });

  it("navigates to the meditation screen", () => {
    render(<App />);
    fireEvent.click(screen.getByRole("button", { name: /冥想练习/ }));
    expect(document.querySelector(".page-meditation")).toBeInTheDocument();
  });

  it("moves from landing to login", () => {
    window.history.replaceState({}, "", "/?screen=landing");
    render(<App />);
    expect(screen.getByRole("heading", { name: /更懂身体/ })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "开始使用" }));
    expect(screen.getByText("欢迎回来")).toBeInTheDocument();
  });
});
