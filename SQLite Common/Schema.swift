//
// SQLite.Schema
// Copyright (c) 2014 Stephen Celis.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

public extension Database {

    public func create(#table: Query, _ block: SchemaBuilder -> ()) -> Statement {
        var builder = SchemaBuilder(table)
        block(builder)
        return builder.statement.run()
    }

    public func drop(#table: Query) -> Statement {
        return run("DROP TABLE \(table.tableName)")
    }

}

public final class SchemaBuilder {

    let table: Query
    var columns = [Expressible]()

    private init(_ table: Query) {
        self.table = table
    }

    public func column<T: Value>(
        name: Expression<T>,
        primaryKey: Bool = false,
        null: Bool = true,
        unique: Bool = false,
        check: Expression<Bool>? = nil,
        defaultValue: T? = nil
    ) {
        column(name, primaryKey, null, unique, check, defaultValue)
    }

    public func column(
        name: Expression<String>,
        primaryKey: Bool = false,
        null: Bool = true,
        unique: Bool = false,
        check: Expression<Bool>? = nil,
        defaultValue: String? = nil,
        collate: Collation
    ) {
        let expressions: [Expressible] = [Expression<()>("COLLATE \(collate.rawValue)")]
        column(name, primaryKey, null, unique, check, defaultValue, expressions)
    }

    public func column(
        name: Expression<Int>,
        primaryKey: Bool = false,
        null: Bool = true,
        unique: Bool = false,
        check: Expression<Bool>? = nil,
        defaultValue: Int? = nil,
        references: Expression<Int>
    ) {
        let expressions: [Expressible] = [Expression<()>("REFERENCES"), namespace(references)]
        column(name, primaryKey, null, unique, check, defaultValue, expressions)
    }

    public func column(
        name: Expression<Int>,
        primaryKey: Bool = false,
        null: Bool = true,
        unique: Bool = false,
        check: Expression<Bool>? = nil,
        defaultValue: Int? = nil,
        references: Query
    ) {
        return column(
            name,
            primaryKey: primaryKey,
            unique: unique,
            check: check,
            defaultValue: defaultValue,
            references: Expression(references.tableName)
        )
    }

    private func column<T: Value>(
        name: Expression<T>,
        _ primaryKey: Bool,
        _ null: Bool,
        _ unique: Bool,
        _ check: Expression<Bool>?,
        _ defaultValue: T?,
        _ expressions: [Expressible]? = nil
    ) {
        var parts: [Expressible] = [name, Expression<()>(T.datatype)]
        if primaryKey { parts.append(Expression<()>("PRIMARY KEY")) }
        if !null { parts.append(Expression<()>("NOT NULL")) }
        if unique { parts.append(Expression<()>("UNIQUE")) }
        if let check = check { parts.append(Expression<()>("CHECK \(check.SQL)", check.bindings)) }
        if let defaultValue = defaultValue { parts.append(Expression<()>("DEFAULT ?", [defaultValue])) }
        if let expressions = expressions { parts += expressions }
        columns.append(SQLite.join(" ", parts))
    }

    public func primaryKey(column: Expressible...) {
        let primaryKey = SQLite.join(", ", column)
        columns.append(Expression<()>("PRIMARY KEY(\(primaryKey.SQL))", primaryKey.bindings))
    }

    public func unique(column: Expressible...) {
        let unique = SQLite.join(", ", column)
        columns.append(Expression<()>("UNIQUE(\(unique.SQL))", unique.bindings))
    }

    public func check(condition: Expression<Bool>) {
        columns.append(Expression<()>("CHECK \(condition.SQL)", condition.bindings))
    }

    public enum Dependency: String {

        case NoAction = "NO ACTION"

        case Restrict = "RESTRICT"

        case SetNull = "SET NULL"

        case SetDefault = "SET DEFAULT"

        case Cascade = "CASCADE"

    }

    public func foreignKey<T: Value>(
        column: Expression<T>,
        references: Expression<T>,
        update: Dependency? = nil,
        delete: Dependency? = nil
    ) {
        var parts: [Expressible] = [Expression<()>("FOREIGN KEY(\(column.SQL)) REFERENCES", column.bindings)]
        parts.append(namespace(references))
        if let update = update { parts.append(Expression<()>("ON UPDATE \(update.rawValue)")) }
        if let delete = delete { parts.append(Expression<()>("ON DELETE \(delete.rawValue)")) }
        columns.append(SQLite.join(" ", parts))
    }

    public func foreignKey<T: Value>(
        column: Expression<T>,
        references: Query,
        update: Dependency? = nil,
        delete: Dependency? = nil
    ) {
        foreignKey(column, references: Expression(references.tableName), update: update, delete: delete)
    }

    private var statement: Statement {
        let expression = SQLite.join(", ", columns)
        let SQL = "CREATE TABLE \(table.tableName) (\(expression.compile()))"
        return table.database.prepare(SQL)
    }

    private func namespace<T: Value>(expression: Expression<T>) -> Expression<T> {
        if !contains(expression.SQL, ".") { return expression }
        let reference = Array(expression.SQL).reduce("") { SQL, character in
            let string = String(character)
            return SQL + (string == "." ? "(" : string)
        }
        return Expression("\(reference))", expression.bindings)
    }

}
