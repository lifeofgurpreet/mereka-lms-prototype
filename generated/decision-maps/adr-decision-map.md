# Decision Map

> Generated file. Do not hand-edit. Regenerate from the ADR source inputs.

```mermaid
graph LR
  ADR-013 -->|depends_on| ADR-029
  ADR-013 -->|depends_on| ADR-031
  ADR-013 -->|read_next| ADR-022
  ADR-018 -->|depends_on| ADR-028
  ADR-018 -->|depends_on| ADR-033
  ADR-022 -->|depends_on| ADR-029
  ADR-022 -->|depends_on| ADR-031
  ADR-022 -->|amends| ADR-002
  ADR-022 -->|amends| ADR-013
  ADR-028 -->|amends| ADR-003
  ADR-028 -->|amends| ADR-019
  ADR-028 -->|amends| ADR-021
  ADR-028 -->|amends| ADR-026
  ADR-028 -->|amends| ADR-027
  ADR-028 -->|read_next| ADR-029
  ADR-028 -->|read_next| ADR-030
  ADR-028 -->|read_next| ADR-031
  ADR-028 -->|read_next| ADR-032
  ADR-028 -->|read_next| ADR-033
  ADR-029 -->|depends_on| ADR-028
  ADR-029 -->|amends| ADR-002
  ADR-029 -->|amends| ADR-005
  ADR-029 -->|amends| ADR-022
  ADR-029 -->|amends| ADR-024
  ADR-029 -->|read_next| ADR-033
  ADR-030 -->|depends_on| ADR-028
  ADR-030 -->|read_next| ADR-031
  ADR-031 -->|depends_on| ADR-028
  ADR-031 -->|depends_on| ADR-030
  ADR-031 -->|amends| ADR-013
  ADR-031 -->|amends| ADR-022
  ADR-032 -->|depends_on| ADR-028
  ADR-032 -->|depends_on| ADR-031
  ADR-032 -->|read_next| ADR-033
  ADR-033 -->|depends_on| ADR-028
  ADR-033 -->|depends_on| ADR-029
  ADR-033 -->|depends_on| ADR-032
  ADR-033 -->|amends| ADR-024
  ADR-034 -->|depends_on| ADR-028
  ADR-034 -->|amends| ADR-008
  ADR-034 -->|read_next| ADR-037
  ADR-035 -->|depends_on| ADR-028
  ADR-035 -->|depends_on| ADR-029
  ADR-035 -->|amends| ADR-014
  ADR-035 -->|amends| ADR-021
  ADR-036 -->|depends_on| ADR-028
  ADR-036 -->|depends_on| ADR-033
  ADR-037 -->|depends_on| ADR-034
  ADR-038 -->|depends_on| ADR-028
  ADR-038 -->|depends_on| ADR-033
  ADR-038 -->|amends| ADR-018
  ADR-039 -->|depends_on| ADR-035
  ADR-040 -->|depends_on| ADR-028
  ADR-040 -->|depends_on| ADR-030
  ADR-040 -->|amends| ADR-006
  ADR-040 -->|amends| ADR-021
  ADR-041 -->|depends_on| ADR-029
  ADR-041 -->|depends_on| ADR-033
  ADR-041 -->|amends| ADR-029
  ADR-041 -->|amends| ADR-033
```
