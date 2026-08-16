import fs from "node:fs/promises"

const PLURAL_DEFAULT_ACTIONS = ["index", "new", "create", "show", "edit", "update", "destroy"]
const SINGULAR_DEFAULT_ACTIONS = ["show", "new", "edit"]

export interface RouteResourceNode {
  key: string
  name: string
  basePath: string
  actions: string[]
  parentKey: string | null
  namespacePrefix: string[]
  singular: boolean
}

export interface SingularResourceGetPath {
  action: "show" | "new" | "edit"
  path: string
}

export function singularResourceGetPaths(resource: RouteResourceNode): SingularResourceGetPath[] {
  if (!resource.singular) return []
  return (["show", "new", "edit"] as const)
    .filter((action) => resource.actions.includes(action))
    .map((action) => ({
      action,
      path: action === "show" ? resource.basePath : `${resource.basePath}/${action}`,
    }))
}

interface ParsedResource {
  name: string
  hasBlock: boolean
  actions: string[]
  singular: boolean
}

interface StackFrame {
  type: "namespace" | "resource" | "block"
  name?: string
  key?: string
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

function splitArgs(argString: string): string[] {
  const result: string[] = []
  let current = ""
  let depth = 0
  let quote: string | null = null

  for (let index = 0; index < argString.length; index += 1) {
    const char = argString[index]
    if (quote) {
      current += char
      if (char === quote && argString[index - 1] !== "\\") quote = null
      continue
    }
    if (char === "'" || char === '"') {
      quote = char
      current += char
      continue
    }
    if (char === "[" || char === "{" || char === "(") depth += 1
    if (char === "]" || char === "}" || char === ")") depth = Math.max(0, depth - 1)
    if (char === "," && depth === 0) {
      if (current.trim()) result.push(current.trim())
      current = ""
      continue
    }
    current += char
  }
  if (current.trim()) result.push(current.trim())
  return result
}

function parseActionList(optionValue: string): string[] {
  const percentMatch = optionValue.match(/^%i(?:\[([^\]]*)\]|\(([^)]*)\))$/)
  const percentActions = percentMatch?.[1] ?? percentMatch?.[2]
  if (percentActions !== undefined) return percentActions.trim().split(/\s+/).filter(Boolean)

  const arrayMatch = optionValue.match(/\[(.*?)\]/)
  if (arrayMatch) {
    return arrayMatch[1].split(",").map((part) => part.replace(/[:\s]/g, "").trim()).filter(Boolean)
  }

  const symbolMatch = optionValue.match(/^:([a-zA-Z0-9_]+)$/)
  return symbolMatch ? [symbolMatch[1]] : []
}

export function parseResourceLine(line: string): ParsedResource | null {
  const match = line.match(/^(resource|resources)\s+:([a-zA-Z0-9_]+)\b(.*)$/)
  if (!match) return null

  const singular = match[1] === "resource"
  const name = match[2]
  let optionString = (match[3] ?? "").trim()
  const hasBlock = optionString.endsWith("do")
  if (hasBlock) optionString = optionString.replace(/\sdo$/, "").trim()
  const options = Object.fromEntries(
    (optionString ? splitArgs(optionString) : [])
      .filter((part) => part.includes(":"))
      .map((part) => {
        const [key, ...rest] = part.split(":")
        return [key.trim(), rest.join(":").trim()]
      }),
  )
  let actions = [...(singular ? SINGULAR_DEFAULT_ACTIONS : PLURAL_DEFAULT_ACTIONS)]
  if (options.only) actions = parseActionList(options.only)
  else if (options.except) {
    const excluded = new Set(parseActionList(options.except))
    actions = actions.filter((action) => !excluded.has(action))
  }
  return { name, hasBlock, actions, singular }
}

export async function discoverResourcesFromRoutes(routesFile: string): Promise<RouteResourceNode[]> {
  const lines = (await fs.readFile(routesFile, "utf8")).split(/\r?\n/)
  const stack: StackFrame[] = []
  const resources: RouteResourceNode[] = []

  for (const rawLine of lines) {
    const line = rawLine.trim()
    if (!line || line.startsWith("#")) continue
    if (line === "end") {
      stack.pop()
      continue
    }
    const namespaceMatch = line.match(/^namespace\s+:([a-zA-Z0-9_]+)\s+do$/)
    if (namespaceMatch) {
      stack.push({ type: "namespace", name: namespaceMatch[1] })
      continue
    }
    const resource = parseResourceLine(line)
    if (!resource) {
      if (line.endsWith(" do")) stack.push({ type: "block" })
      continue
    }
    const namespacePrefix = stack.filter((frame) => frame.type === "namespace").map((frame) => frame.name as string)
    const parentResource = [...stack].reverse().find((frame) => frame.type === "resource")
    const parentKey = parentResource?.key ?? null
    const segments = parentResource
      ? [...namespacePrefix, parentResource.name as string, resource.name]
      : [...namespacePrefix, resource.name]
    const node: RouteResourceNode = {
      key: slugify(segments.join("-")),
      name: resource.name,
      basePath: `/${segments.join("/")}`,
      actions: resource.actions,
      parentKey,
      namespacePrefix,
      singular: resource.singular,
    }
    resources.push(node)
    if (resource.hasBlock) stack.push({ type: "resource", name: resource.name, key: node.key })
  }
  return resources
}
