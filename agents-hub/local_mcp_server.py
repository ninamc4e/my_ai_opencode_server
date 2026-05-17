import math
from mcp.server.fastmcp import FastMCP

app = FastMCP("local_calculator", json_response=True)

@app.tool(description="Calculate: add, subtract, multiply, divide, power, sqrt, sin, cos")
def calculate(operation: str, a: float, b: float = 0) -> str:
    op = operation.strip().lower()
    if op == "add":
        return f"{a} + {b} = {a + b}"
    elif op == "subtract":
        return f"{a} - {b} = {a - b}"
    elif op == "multiply":
        return f"{a} * {b} = {a * b}"
    elif op == "divide":
        if b == 0:
            return "Error: division by zero"
        return f"{a} / {b} = {a / b}"
    elif op == "power":
        return f"{a} ^ {b} = {a ** b}"
    elif op == "sqrt":
        if a < 0:
            return "Error: sqrt of negative number"
        return f"sqrt({a}) = {math.sqrt(a)}"
    elif op == "sin":
        return f"sin({a}) = {math.sin(a)}"
    elif op == "cos":
        return f"cos({a}) = {math.cos(a)}"
    else:
        return f"Unknown operation: {op}. Use: add, subtract, multiply, divide, power, sqrt, sin, cos"

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app.streamable_http_app(), host="127.0.0.1", port=8765)
