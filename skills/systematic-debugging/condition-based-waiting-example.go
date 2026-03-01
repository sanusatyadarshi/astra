// Complete implementation of condition-based waiting utilities
// From: Lace test infrastructure improvements (2025-10-03)
// Context: Fixed 15 flaky tests by replacing arbitrary timeouts

package waitutil

import (
	"context"
	"fmt"
	"time"
)

// Event represents a generic event from a thread.
type Event struct {
	Type string
	Data map[string]any
}

// EventSource provides access to events from a thread.
type EventSource interface {
	GetEvents(threadID string) []Event
}

// WaitForEvent polls until an event of the given type appears in the thread.
//
// Example:
//
//	event, err := WaitForEvent(ctx, source, threadID, "TOOL_RESULT", 5*time.Second)
func WaitForEvent(ctx context.Context, src EventSource, threadID, eventType string, timeout time.Duration) (Event, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()

	for {
		events := src.GetEvents(threadID)
		for _, e := range events {
			if e.Type == eventType {
				return e, nil
			}
		}

		select {
		case <-ctx.Done():
			return Event{}, fmt.Errorf("timeout waiting for %s event after %v", eventType, timeout)
		case <-ticker.C:
			// poll again
		}
	}
}

// WaitForEventCount polls until at least count events of the given type appear.
//
// Example:
//
//	// Wait for 2 AGENT_MESSAGE events (initial response + continuation)
//	events, err := WaitForEventCount(ctx, source, threadID, "AGENT_MESSAGE", 2, 5*time.Second)
func WaitForEventCount(ctx context.Context, src EventSource, threadID, eventType string, count int, timeout time.Duration) ([]Event, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()

	for {
		events := src.GetEvents(threadID)
		var matching []Event
		for _, e := range events {
			if e.Type == eventType {
				matching = append(matching, e)
			}
		}
		if len(matching) >= count {
			return matching, nil
		}

		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("timeout waiting for %d %s events after %v (got %d)", count, eventType, timeout, len(matching))
		case <-ticker.C:
		}
	}
}

// WaitForEventMatch polls until an event satisfying the predicate appears.
//
// Example:
//
//	// Wait for TOOL_RESULT with specific ID
//	event, err := WaitForEventMatch(ctx, source, threadID,
//	    func(e Event) bool { return e.Type == "TOOL_RESULT" && e.Data["id"] == "call_123" },
//	    "TOOL_RESULT with id=call_123", 5*time.Second)
func WaitForEventMatch(ctx context.Context, src EventSource, threadID string, predicate func(Event) bool, description string, timeout time.Duration) (Event, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()

	for {
		events := src.GetEvents(threadID)
		for _, e := range events {
			if predicate(e) {
				return e, nil
			}
		}

		select {
		case <-ctx.Done():
			return Event{}, fmt.Errorf("timeout waiting for %s after %v", description, timeout)
		case <-ticker.C:
		}
	}
}

// Usage example from actual debugging session:
//
// BEFORE (flaky):
// ---------------
//   messagePromise := agent.SendMessage("Execute tools")
//   time.Sleep(300 * time.Millisecond)  // Hope tools start in 300ms
//   agent.Abort()
//   <-messagePromise
//   time.Sleep(50 * time.Millisecond)   // Hope results arrive in 50ms
//   assert(len(toolResults) == 2)       // Fails randomly
//
// AFTER (reliable):
// ----------------
//   messagePromise := agent.SendMessage("Execute tools")
//   WaitForEventCount(ctx, source, threadID, "TOOL_CALL", 2, 5*time.Second) // Wait for tools to start
//   agent.Abort()
//   <-messagePromise
//   WaitForEventCount(ctx, source, threadID, "TOOL_RESULT", 2, 5*time.Second) // Wait for results
//   assert(len(toolResults) == 2) // Always succeeds
//
// Result: 60% pass rate -> 100%, 40% faster execution
