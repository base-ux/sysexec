BEGIN {
    # Global constants
    NULL	= 0
    FALSE	= 0
    TRUE	= 1

    # Regular expressions
    RE_SKIP	= "^[\t ]*(#|$)"
    RE_COMMENT	= "[\t ]*#.*$"
    RE_HOST	= "^!?[^!%]"
    RE_GROUP	= "^!?%"
    RE_NEG	= "^!"
    RE_OP	= "^(<|>)$"
    RE_TRIM	= "(^(\n|[\t ])+|(\n|[\t ])+$)"
    RE_DELIM	= "[\t ]*(\n+[\t ]*)+"
    RE_SPECIAL	= "[.[(+{|$]"
    RE_STAR	= "[*]"
    RE_QMARK	= "[?]"

    # Modes
    MODE_NONE	= 0
    MODE_HOST	= 1
    MODE_GROUP	= 2
    MODE_FILT	= 3

    # Node Types
    T_HOST	= 0
    T_GROUP	= 1

    # Graph orientation
    G_LEFT	= 0
    G_RIGHT	= 1

    # Default values for global variables
    GraphMode	= G_LEFT
    PrintType	= T_HOST
    HasHostFilter	= FALSE
    HasGroupFilter	= FALSE
    StdErr	= TRUE
    ErrStream	= "/dev/stderr"

    # Process variables passed by '-v'
    CommonOnly = (OFLAG != "" && OFLAG != 0)
    if (MASK != "")	processFilter(MASK, TRUE)
    if (REGEX != "")	processFilter(REGEX)

    Mode = (HasGroupFilter) ? MODE_FILT : MODE_HOST
    if (GRP != "") {
	PrintType = T_GROUP
	if (GRP == "group") {
	    Mode = MODE_GROUP
	} else if (GRP == "child") {
	    Mode = (HasGroupFilter) ? MODE_FILT : MODE_GROUP
	} else if (GRP == "parent") {
	    GraphMode = G_RIGHT
	    Mode = (HasHostFilter || HasGroupFilter) ? MODE_FILT : MODE_NONE
	} else {
	    Mode = MODE_NONE
	}
    }
    if (Mode == MODE_NONE) exit

    # Detect stderr stream availability
    if (system("test -c " ErrStream) != 0) {
	StdErr = FALSE
	ErrStream = "cat >&2"
    }
}

################

$0 ~ RE_SKIP	{ next }		# Skip empty lines and comments
$0 ~ RE_COMMENT	{ sub(RE_COMMENT, "") }	# Remove inline comment

$1 ~ RE_OP {
    err("host or group missing")
    next
}

NF > 1 && $2 !~ RE_OP {
    err(sprintf("unknown operator '%s'", $2))
    next
}

$1 ~ RE_HOST && $2 == "<" {
    err("illegal operator '<' for host record")
    next
}

Mode == MODE_HOST {
    if ($1 ~ RE_HOST) {
	createNode($1)
    } else {
	processFields(RE_HOST)
    }
    next
}

Mode == MODE_GROUP {
    if ($1 ~ RE_GROUP) {
	createNode($1)
    }
    processFields(RE_GROUP)
    next
}

Mode == MODE_FILT {
    assignFields()
    next
}

################

function errx(msg) {
    if (StdErr)	{
	print msg > ErrStream
    } else {
	print msg | ErrStream
    }
}

function err(msg) {
    errx(sprintf("%s:%d: %s", FILENAME, FNR, msg))
}

################

function trimDelim(s) {
    if (s ~ RE_DELIM) gsub(RE_DELIM, "\n", s)	# Replace all delimiters with single '\n'
    if (s ~ RE_TRIM) gsub(RE_TRIM, "", s)	# Trim spaces
    return s
}

function processFilter(filt, convert,   a, e) {
    split(trimDelim(filt), a, "\n")
    for (e in a) {
	createFilter((convert) ? convertMask(a[e]) : a[e])
    }
}

function convertMask(mask) {
    if (mask != "") {
	gsub(RE_SPECIAL, "[&]", mask)
	gsub(RE_STAR, ".*", mask)
	gsub(RE_QMARK, ".", mask)
	gsub(/\^/, "[\\^]", mask)	# Escape circumflex
	gsub(/\\/, "&&", mask)		# Escape backslash
	if (mask ~ /^%/) {
	    sub(/^%/, "%^", mask)	# Switch group attribute
	} else {
	    mask = "^" mask
	}
	mask = mask "$"
    }
    return mask
}

function createFilter(regex) {
    if (regex ~ /^%?$/) return		# Skip empty filter
    if (regex ~ /^%/) {
	GFilter[substr(regex, 2)] = 1
	HasGroupFilter = TRUE
    } else {
	HFilter[regex] = 1
	HasHostFilter = TRUE
    }
}

function _isFiltered(s, aFilter, first,   e, found) {
    found = TRUE
    for (e in aFilter) {
	found = (s ~ e)
	if ((first && found) || (!first && !found)) break
    }
    return found
}

function isFiltered(s, type, first) {
    first = (first || !CommonOnly)
    if (type == T_HOST && HasHostFilter) {
	return _isFiltered(s, HFilter, first)
    } else if (type == T_GROUP && HasGroupFilter) {
	return _isFiltered(substr(s, 2), GFilter, first)
    }
    return TRUE
}

################

function processFields(re,   nField) {
    for (nField = 3; nField <= NF; nField++) {
	if ($nField ~ re) {
	    createNode($nField)
	}
    }
}

function assignFields(   rightop, left, right, lNode, rNode, lNeg, rNeg, nField) {
    rightop = ($2 == ">")
    left = $1
    lNode = createNode(left)
    lNeg = (left ~ RE_NEG)
    for (nField = 3; nField <= NF; nField++) {
	right = $nField
	rNeg = (right ~ RE_NEG)
	if (right ~ RE_HOST && rightop) {
	    err(sprintf("can't use host '%s' with '>' operator", right))
	    continue
	}
	if (lNeg && rNeg) {
	    err(sprintf("both '%s' and '%s' are negative", left, right))
	    continue
	}
	rNode = createNode(right)
	if (lNode != NULL && rNode != NULL && lNode != rNode) {
	    if (rightop) {
		XEdge[rNode, lNode] = (lNeg || rNeg) ? -1 : 1
	    } else {
		XEdge[lNode, rNode] = (lNeg || rNeg) ? -1 : 1
	    }
	}
    }
}

function isHostCompliant(s) {
    if (Mode == MODE_HOST || (Mode == MODE_FILT && PrintType == T_HOST)) {
	return isFiltered(s, T_HOST)
    }
    if (Mode == MODE_FILT && GraphMode == G_RIGHT) {
	return (HasHostFilter && isFiltered(s, T_HOST, TRUE))
    }
    return FALSE
}

function isGroupCompliant(s) {
    return (Mode != MODE_GROUP || isFiltered(s, T_GROUP))
}

function isHostToFilt(s) {
    return (GraphMode == G_RIGHT)
}

function isGroupToFilt(s) {
    return (Mode == MODE_FILT && HasGroupFilter && isFiltered(s, T_GROUP, TRUE))
}

function createNode(s,   create, fnode, type) {
    if (s ~ RE_NEG) sub(RE_NEG, "", s)		# Trim '!' at the beginning
    if (!(s in XNode)) {
	type = (s ~ RE_HOST) ? T_HOST : T_GROUP
	create = (type == T_HOST) ? isHostCompliant(s) : isGroupCompliant(s)
	if (create) {
	    XNode[s] = ++NodeIdx
	    Node[NodeIdx] = s
	    NodeType[NodeIdx] = type
	    fnode = (type == T_HOST) ? isHostToFilt(s) : isGroupToFilt(s)
	    if (fnode) {
		FNode[NodeIdx] = 1
	    }
	} else {
	    XNode[s] = NULL
	}
    }
    return XNode[s]
}

################

function setBlock(ent,   i) {
    if (ent in BGraph) {
	for (i = 1; i <= BGraph[ent]; i++) {
	    ++BNode[BGraph[ent, i]]
	}
    }
}

function unsetBlock(ent,   e, i) {
    if (ent in BGraph) {
	for (i = 1; i <= BGraph[ent]; i++) {
	    e = BGraph[ent, i]
	    if (--BNode[e] == 0) delete BNode[e]
	}
    }
}

function expand(ent, color,   e, i, n) {
    setBlock(ent)
    VNode[ent] = color
    ++RNode[ent]
    if (ent in Graph) {
	n = Graph[ent]; i = 1
	while (i <= n) {
	    e = Graph[ent, i++]
	    if (VNode[e] != color && !(e in BNode)) {
		expand(e, color)
	    }
	}
    }
    unsetBlock(ent)
}

function addToGraph(graph, lNode, rNode) {
    if (GraphMode == G_LEFT) {
	graph[lNode, ++graph[lNode]] = rNode
    } else {
	graph[rNode, ++graph[rNode]] = lNode
    }
}

function buildGraph(   block, e, n, lNode, rNode) {
    for (e in XEdge) {
	block = (XEdge[e] == -1)
	n = index(e, SUBSEP)
	lNode = substr(e, 1, n-1) + 0
	rNode = substr(e, n+1) + 0
	if (block) {
	    addToGraph(BGraph, lNode, rNode)
	} else {
	    addToGraph(Graph, lNode, rNode)
	}
    }
}

################

function printNodes(   i) {
    for (i = 1; i <= NodeIdx; i++) {
	print Node[i]
    }
}

function printFilter(   e, i, n) {
    buildGraph()
    for (e in FNode) {
	expand(e, ++n)
    }
    for (i = 1; i <= NodeIdx; i++) {
	if (NodeType[i] == PrintType && (i in RNode)) {
	    if (CommonOnly && RNode[i] != n) continue
	    print Node[i]
	}
    }
}

################

END {
    if (Mode == MODE_NONE) exit
    if (Mode == MODE_FILT) {
	printFilter()
    } else {
	printNodes()
    }
}
